#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  ファイル copy
#
require 'shellwords'
require 'net/ssh'
require "socket"
require 'digest/md5'

class FileCopy

  LockFile = TSDir + "/scp.lock"

  def initialize(  )
  end

  #  
  #  排他制御
  #
  def lock( lockf = LockFile )

    File.open( lockf, File::RDWR|File::CREAT, 0644) do |fl|
      if fl.flock(File::LOCK_EX|File::LOCK_NB) == false
        DBlog::debug( nil,"scp locked")
        return false
      else
        yield
      end
    end
    if test(?f, lockf )
      #puts( "lock file delete")
      File.unlink( lockf )
    end
    true
  end

  def start( time_limit )
    lock() { start2( time_limit ) }
  end
  
  def start2( time_limit )
    
    reserve  = DBreserve.new
    list = nil
    DBaccess.new().open( tran: true ) do |db|
      ret = DBkeyval.new.select( db, "tsft" )
      if ret == "true"
        return 
      end
      list = reserve.getTSFT( db )
      DBlog::debug( db,"転送開始") if list.size > 0
      DBkeyval.new.upsert( db, StatConst::KeyName, StatConst::FileCopy )
    end

    abNormal = []
    list.each do |l|

      if $recCount > 0
        DBlog::sto("rec now ssh_ncbreak" )
        break
      end

      path = TSDir + "/"
      if l[:subdir] != nil and l[:subdir] != ""
        subdir2 = Commlib::normStr( l[:subdir] )
        path += subdir2.sub(/^\//,'').sub(/\/$/,'').strip + "/"
      end
      path += l[:fname]

      if test( ?f , path )
        size = File.size( path )
        t = (Time.now + (size / (TSFT_rate * 2  ** 20))).to_i
        if t > time_limit
          DBlog::stoD( sprintf("time limit pass %d", t - time_limit ))
          next
        end

        if $debug == true
          if l[:subdir] =~ /TEST/
            DBlog::sto( "転送 skip #{l[:fname]}")
            DBaccess.new().open do |db|
              reserve.updateStat( db, l[:id], ftp_stat: RsvConst::Ftp_Complete )
            end
            next
          end
        end
        
        ( speed, errmsg )  = scp( TSFT_toDir, subdir2, path )
        if speed > 0
          DBaccess.new().open( tran: true ) do |db|
            tmp = sprintf("転送終了: %s (%.1f Mbyte/sec)", l[:fname], speed )
            DBlog::info(db,tmp)
            reserve.updateStat( db, l[:id], ftp_stat: RsvConst::Ftp_Complete )
          end
        else
          tmp = sprintf("転送失敗: %s : %s", errmsg, l[:fname] )
          DBlog::warn(nil,tmp)
        end
      else
        abNormal << [ l[:id], l[:fname] ]
      end
    end
    if abNormal.size > 0
      DBaccess.new().open( tran: true ) do |db|
        abNormal.each do |tmp|
          ( id, fname ) = tmp
          reserve.updateStat( db, id, ftp_stat: RsvConst::Ftp_AbNormal)
          tmp = sprintf("転送失敗: file not found : %s", fname )
          DBlog::warn( db,tmp)
        end
        DBkeyval.new.upsert( db, StatConst::KeyName, StatConst::None )
      end
    end

  end

  

  #
  #  scp によるファイル転送
  #
  def scp( toDir, subDir, fromFname )

    st = Time.now
    toDir2  = toDir
    if subDir != nil and subDir != ""
      toDir2  = File.join( toDir, subDir )
    end
    toPath = File.join( toDir2, File.basename( fromFname ))
    toDir3 = Shellwords.shellescape( toDir2 )

    errmsg = nil

    def ssh_exec( ssh, cmd, n = 0 )
      #DBlog::stoD( "scp#{n}a: " + cmd.to_s )
      ret = ssh.exec!( cmd )
      #DBlog::stoD( "scp#{n}b: " + ret )
      return ret
    end
    
    begin
      Net::SSH.start( TSFT_host, TSFT_user ) do |ssh|
        ret = ssh_exec( ssh, "echo testOK" )
        if ret =~ /testOK/
          cmd = %Q( test -d #{toDir} && echo OK )
          ret = ssh_exec( ssh, cmd, 1 )
          unless ret =~ /OK/
            errmsg = "転送先 Dir がありません。"
          else
            cmd = %Q( test -d #{toDir3} || mkdir -p #{toDir3} )
            ret = ssh_exec( ssh, cmd, 2 )
            cmd = %Q( test -d #{toDir3} && echo OK )
            ret = ssh_exec( ssh, cmd, 3 )
            unless ret =~ /OK/
              errmsg = "転送先 Dir がありません。"
            end
          end
        else
          errmsg = "ssh で接続出来ませんでした。(echo test)"
        end
      end
    rescue
      puts $!
      puts $@
      errmsg = "ssh で接続出来ませんでした。(open error)" if errmsg == nil
    end
    if errmsg != nil
      return  [ 0, errmsg ]
    end

    cmd = [ "scp", fromFname, "#{TSFT_user}@#{TSFT_host}:#{toPath}" ]
    #DBlog::stoD( "scp: " + cmd.join(" ") )
    pid = spawn( *cmd )
    paid, status = Process.wait2( pid )
    DBlog::stoD( "status: " + status.to_s )
    if status.exitstatus != 0
      DBlog::sto( "error scp cmd=#{cmd}") 
      return  [ 0, "scp error" ]
    end
    
    lap = Time.now - st
    fs = File.size( fromFname )
    fs2 = fs / 2 ** 20
    speed = fs2 / lap
    #printf( "lap = %.2f  fileSize = %d Mbyte speed = %d Mbyte/sec\n",lap, fs2, speed )

    return  [ speed, nil ]
  end
  
end
  
