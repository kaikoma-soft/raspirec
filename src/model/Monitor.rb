# coding: utf-8

#
#   モニター
#
require 'find'
require 'sys/filesystem'

class MonitorM

  FfmpegPidFname = ::StreamDir + "/ffmpeg.pid" 
  Recpt1PidFname = ::StreamDir + "/recpt1.pid"
  TouchFname     = ::StreamDir + "/m3u8.touch"
  PlayListPath   = ::StreamDir + "/" + Const::PlayListFname
  

  def initialize()
    @threads = []
  end

  #
  #  後始末
  #
  def osoji()

    ret = false
    [ Recpt1PidFname, FfmpegPidFname].each do |fname|
      if test(?f, fname )
        begin
          kill_pidfile( fname )
          File.unlink( fname )
          ret = true
          sleep(1)
        rescue Errno::ESRCH
          ;
        end
      end
    end

    File.unlink( Const::PlayListFname ) if File.exist?( Const::PlayListFname )

    Dir.open( StreamDir ).each do |fname|
      if fname =~ /\.(log|ts|pid|m3u8|touch)$/
        path = StreamDir + "/" + fname
        File.unlink( path ) if test( ?f, path )
      end
    end

    @threads.each do |th|
      th.kill
    end

    return ret
  end
  

  #
  #   チューナーをopen
  #
  def tuner_cmd( chid )

    args = [ Recpt1_cmd ]
    DBaccess.new().open do |db|
      channel = DBchannel.new
      row = channel.select( db, chid: chid )
      if row.size > 0
        args += Recpt1_opt
        data = row.first
        case data[:band]
        when Const::GR
          args << data[:stinfo_tp].to_s
        when Const::BS
          args << sprintf("%s_%s",data[:stinfo_tp], data[:stinfo_slot] )
        when Const::CS
          args << data[:stinfo_tp].to_s
        end
        args += [ "--sid", data[:svid].to_s, "3600" ]
        return [ args.join(" "), "-" ]
      else
        raise "channel 取得出来ませんでした。(chid = #{chid})"
      end
    end

    return nil
  end
    
  #
  #   録画中のファイルをopen
  #
  def recnow( args, seek: true )

    #pp "recnow( #{args} )"
    path = nil
    reserve = DBreserve.new
    DBaccess.new().open do |db|
      row = reserve.select( db, id: args.to_i )
      if row.size > 0
        l = row.first
        tmp = Commlib::makeTSfname( l[:subdir], l[:fname] )
        if test( ?f, tmp )
          size = File.size( tmp )
          buf = 10 * Const::MB
          if size > buf
            return [ %Q( tail -c #{buf} -f ), tmp ]
          else
            return [ %Q( cat ), tmp ]
          end
        else
          raise "file not found #{tmp}"
        end
      else
        raise "not found id = #{args}"
      end
    end

    return nil
  end
  
  #
  #   録画済みのファイルをopen
  #
  def file( args )
    path = CGI.unescape( args )
    path2 = TSDir + "/" + path
    if test( ?f, path2 )
      return [ %Q( cat ), path2 ]
    else
      raise "file not found #{path2}"
    end
    return nil
  end

  #
  #  ストリーム開始
  #
  def start( type, args )

    osoji()

    begin
      cmd = case type
            when "ch"   then tuner_cmd( args )
            when "rec"  then recnow( args )
            when "file" then file( args )
            end
    rescue => e
      DBlog::error( nil, "Error: #{e}" )
    end

    if cmd != nil
      if File.executable?(HlsConvCmd)
        pid = fork do
          Process.setpgrp
          ENV["SOURCE_CMD"] = cmd[0]
          ENV["SOURCE_OUT"] = cmd[1]
          ENV["STREAM_DIR"] = StreamDir
          ENV["PLAYLIST"]   = Const::PlayListFname
          exec( HlsConvCmd )
        end
      else
        DBlog::error( nil, "Error: HlsConvCmd が存在しないか、実行可能ではありません。" )
      end
        
      write_pidfile( pid, FfmpegPidFname )
      $childPid[ pid ] = true

      #
      #  処理開始待ち
      #
      count = 0
      while true
        unless test(?f, PlayListPath )
          count += 1
          if count > 60
            DBlog::error( nil, "Error: HLS が生成されませんでした。" )
            osoji()
            return
          end
        else
          DBlog::sto( "found #{Const::PlayListFname}" )
          break
        end
        sleep(1)
      end
      
      #
      #   終了監視ループ
      #
      Thread.new do
        begin
          endCount = 10
          playFlag = false
          while true

            if test(?f, PlayListPath )
              playFlag = true
            else
              break if playFlag == true
            end
            
            if test(?f, TouchFname )
              if ( Time.now - File.mtime( TouchFname )) > 60
                endCount = -1
              end
            else
              endCount -= 1
            end
            #DBlog::sto( "endCount = #{endCount}" )
            if endCount < 0
              osoji()
              break
            end
            sleep(10)
          end
        end
        DBlog::sto( "*** Thread End ***" )
      end
    end
  end

  def write_pidfile( pid, fname )
    File.open( fname, "w" ) do |fp|
      fp.puts( pid.to_s )
    end
  end

  def kill_pidfile( fname )
    File.open( fname, "r" ) do |fp|
      pid = fp.gets.chomp.to_i
      if pid > 0
        DBlog::debug( nil, "kill #{pid} <- #{fname}" )
        Process.kill(:HUP, -1 * pid)
      end
    end
  end

  
end

    
