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
  #  ssh & nc によるファイル転送
  #
  def ssh_nc( toDir, subDir, fromFname )
    if subDir != nil and subDir != ""
      toDir2  = Shellwords.escape(toDir + "/" + subDir)
    else
      toDir2  = Shellwords.escape(toDir)
    end
    fname   = Shellwords.escape( File.basename( fromFname ))
    
    
    cmds = [ %Q(test -d #{toDir2} || mkdir -p #{toDir2}),
             sprintf("%s -l %s > %s/%s &",TSFT_ncbin,TSFT_ncport,toDir2,fname ),
           ]
    Net::SSH.start( TSFT_host, TSFT_user ) do |ssh|
      cmds.each do |cmd|
        cmd.force_encoding("ASCII-8BIT")
        ssh.exec!( cmd )
      end
    end

    sleep 5
    st = Time.now
    begin
      digest = Digest::MD5.new
      sock = TCPSocket.open( TSFT_host, TSFT_ncport )
      bsize = 1024 * 256
      outbuf = "x" * bsize;
      
      File.open( fromFname, "r") do |fpr|
        while fpr.read( bsize, outbuf) != nil
          sock.write(outbuf)
          digest.update(outbuf)
        end
      end
      sock.close
    rescue
      return [ 0, "write error" ]
    end
    
    Net::SSH.start( TSFT_host, TSFT_user ) do |ssh|
      str = "#{TSFT_md5bin} #{toDir2}/#{fname}".force_encoding("ASCII-8BIT")
      ssh.exec!( str ).each_line do |line|
        if line =~ /(\h{32})\s/
          md5 = $1
          if digest.hexdigest != md5
            return [ 0, "MD5 chk fail" ]
          end
        end
      end
    end

    lap = Time.now - st
    fs = File.size( fromFname )
    fs2 = fs / 2 ** 20
    speed = fs2 / lap
    #printf( "lap = %.2f  fileSize = %d Mbyte speed = %d Mbyte/sec\n",lap, fs2, speed )
    return  [ speed, nil ]
    
  end


  #
  #  scp によるファイル転送
  #
  def scp( toDir, subDir, fromFname )

    st = Time.now

    toDir2  = Shellwords.escape(toDir)
    if subDir != nil and subDir != ""
      toDir3  = Shellwords.escape(toDir + "/" + subDir)
    else
      toDir3  =  toDir2
    end
    fname = Shellwords.escape( fromFname  )

    errmsg = nil
    mkdir = %Q(test -d #{toDir3} || mkdir -p #{toDir3})
    begin
      Net::SSH.start( TSFT_host, TSFT_user ) do |ssh|
        ret = ssh.exec!( "echo testOK" )
        if ret =~ /testOK/
          cmd = "test -d #{toDir2} && echo found"
          ret = ssh.exec!( cmd.force_encoding("ASCII-8BIT") )
          unless ret =~ /found/
            errmsg = "転送先 Dir がありません。"
          else
            ssh.exec!( mkdir.force_encoding("ASCII-8BIT") )
            cmd = "test -d #{toDir3} && echo found"
            ret = ssh.exec!( cmd.force_encoding("ASCII-8BIT") )
            unless ret =~ /found/
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

    cmd = %Q(scp #{fname} #{TSFT_user}@#{TSFT_host}:"#{toDir3}")
    ret = system( cmd )
    if ret != true
      DBlog::debug( nil,"error scp cmd=#{cmd}") 
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
  
