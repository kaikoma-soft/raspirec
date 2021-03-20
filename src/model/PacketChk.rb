#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  パケットチェック
#

class PacketChk < FileCopy      # FileCopy を流用


  def initialize(  )
    @reserve  = DBreserve.new
  end

  def start( time_limit )
    lock() { start2( time_limit ) }
  end
  
  def start2( time_limit )
    
    list = nil
    DBaccess.new().open do |db|
      db.transaction do
        list = @reserve.getPacketChk( db )
        DBkeyval.new.upsert( db, StatConst::KeyName, StatConst::PacketChk )
      end
    end
    DBlog::sto( "Packet Check 開始 #{list.size}") if list.size > 0

    abNormal = []
    list.each do |l|

      if $recCount > 0          # 録画中は実行しない
        DBlog::sto("rec now -> Packet Check 停止" )
        break
      end
      next if l[:fname] == nil
      
      path = TSDir + "/"
      if l[:subdir] != nil and l[:subdir] != ""
        subdir2 = Commlib::normStr( l[:subdir] )
        path += subdir2.sub(/^\//,'').sub(/\/$/,'').strip + "/"
      end
      path += l[:fname]
      DBlog::sto( path );

      if test( ?f , path )
        size = File.size( path )
        t = Time.now + (size / (PacketChk_rate * 2  ** 20)).to_i
        if t > time_limit
          DBlog::debug( nil, sprintf("time limit %s > %s", t, time_limit ))
          next
        end

        ( drer, pcr, speed ) = run( path )
        pcr = pcr == "OK" ? 0 : 1 if pcr != 0

        if speed > 0
          DBaccess.new().open do |db|
            db.transaction do
              tmp = sprintf("PacketChk 終了: %s (%.1f Mbyte/sec)", l[:fname], speed )
              DBlog::info(db,tmp)
              val = @reserve.makeDropNum( drer, pcr, 0 )
              @reserve.updateStat( db, l[:id], dropNum: val )
            end
          end
        else
          tmp = sprintf("PacketChk 失敗: %s", l[:fname] )
          DBlog::warn(nil,tmp)
          abNormal << [ l[:id], l[:fname] ]
        end
      else
        tmp = sprintf("PacketChk 失敗: %s", l[:fname] )
        DBlog::sto( tmp )
        abNormal << [ l[:id], l[:fname] ]
      end
    end

    DBaccess.new().open do |db|
      db.transaction do
        if abNormal.size > 0
          abNormal.each do |tmp|
            ( id, fname ) = tmp
            val = @reserve.makeDropNum( 0, 0, 1 )
            @reserve.updateStat( db, id, dropNum: val )
          end
        end
        DBkeyval.new.upsert( db, StatConst::KeyName, StatConst::None )
      end
    end

    
  end

  #
  #  tspacketchk の実行
  #
  def run( path )

    args = [ PacketChk_cmd ]
    args += PacketChk_opt.split().push( path )
    drer = pcr = speed = 0

    logfname = path + ".chk"
    File.open(logfname, File::RDWR|File::CREAT, 0644) do |fl|
      if fl.flock(File::LOCK_EX|File::LOCK_NB) == false
        DBlog::debug( nil,"chk log locked(#{path})")
      else
        IO.popen( args, "r") do |io|
          io.each_line do |line|
            if line =~ /drop\+error\s+=\s+(\d+)/
              drer = $1.to_i
            elsif line =~ /Check Time.*?\(([\d\.]+) Mbyte\/sec/
              speed = $1.to_f
            elsif line =~ /PCR Wrap-around check\s+=\s+(OK|NG)/i
              pcr = $1
            end
            fl.puts( line )
          end
        end
      end
    end
    return [ drer,pcr,speed]
  end
end
