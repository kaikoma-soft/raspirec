#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#   recpt1 コマンド関係
#

require 'open3'
require 'timeout'


class ExecError < StandardError; end

class Recpt1

  @@epgPid = []                 # EPG取得時の pid

  def initialize( )
    @endTime = nil #Time.now.to_i + 600
  end

  def clearEpgPid()
    @@epgPid = []
  end

  def addEpgPid(pid)
    $mutex = Mutex.new if $mutex == nil
    $mutex.synchronize do
      @@epgPid << pid
    end
  end

  def killEpgPid()
    DBlog::stoD( "killEpgPid()" )
    count = 0
    while @@epgPid.size > 0
      pid = @@epgPid.shift
      begin
        Process.kill(:HUP, pid );
        Process.waitpid( pid, Process::WNOHANG )
        count += 1
      rescue Errno::ECHILD,Errno::ESRCH
      end
      DBlog::stoD( "killEpgPid() kill #{pid}" )
    end
    
    return count
  end
  
  #
  #   epg データを取得
  #
  def getEpgJson( ch, time, outfname )
    bsize = 1024
    errbuf = ""
    loop = true
    outbuf = "x" * bsize;
    arg1 = makeCmd( ch, time, sid: "epg", outfn: "-" )
    arg2 = %W( #{Epgdump} json - #{outfname} )
    ndc = 0                       # no data count
    startTime = Time.now
    cn = 0

    Open3.popen3(*arg2) do |stdin2, stdout2, stderr2, wait2|
      Open3.popen3(*arg1) do |stdin1, stdout1, stderr1, wait1|
        stdin1.close

        $rec_pid[ wait1.pid ] = true
        $rec_pid[ wait2.pid ] = true
        addEpgPid( wait1.pid )
        
        begin
          time2 = ( time + 3 ).to_i
          Timeout.timeout( time2 ) do
            while loop do
              if ( r = IO.select( [stdout1,stderr1], nil, nil, 1)) != nil
                begin
                  r[0].each do |fp|
                    if fp == stdout1
                      stdout1.read_nonblock( bsize, outbuf)
                      stdin2.write( outbuf ) if stdin2 != nil
                    elsif fp == stderr1
                      stderr1.read_nonblock( bsize, outbuf)
                      if outbuf =~ /C\/N = ([\d\.]+)dB/i
                        cn = $1.to_f
                      end
                      #$stderr.write( outbuf )
                    end
                  end
                rescue IO::EAGAINWaitReadable => e
                rescue EOFError => e
                  loop = false
                end
                ndc = 0
              else
                ndc += 1
                if ndc > 8
                  #puts("no data time out")
                  loop = false
                  #pp wait1.pid
                  Process.kill(:TERM, wait1.pid )
                end
              end
            end
          end
        rescue Errno::EPIPE
          DBlog::sto("getEpgJson() Broken pipe;  kill #{wait1.pid}" )
          Process.kill(:KILL, wait1.pid)
        rescue Timeout::Error
          #DBlog::sto("getEpgJson() timer timeout ; kill #{wait1.pid}" )
          Process.kill(:KILL, wait1.pid)
        end
        stdin2.close
      end
      #sleep(1)
    end

    if ( Time.now - startTime ) < 3
      raise ExecError
    end
    cn
  end


  #
  #   epg データを取得 ( retry 付き )
  #
  def getEpgJson_retry( ch, time, outfname )
    retry_counter = 0
    begin
      r = getEpgJson( ch, time, outfname )
    rescue ExecError => e
      puts("retry")
      retry_counter += 1
      if retry_counter < 10
        sleep(3)
        retry
      end
    end
    r
  end

  #
  #  終了時間の設定
  #
  def setEndTime( endTime )
    @endTime = endTime
  end
  
  #
  #   録画の実行
  #
  def recTS( args, outfname, waitT, endTime = nil )

    @endTime = endTime if endTime != nil
    raise ExecError if test(?f, outfname )      # 出力ファイルが既に有る

    
    pid = fork do
      now = Time.now
      txt = sprintf("%s: %s\n",now.strftime("%H:%M:%S"),args.join(" "))
      STDOUT.puts( txt )
      STDOUT.flush
      exec( *args, :err=>:out )
    end
    $rec_pid[ pid ] = true

    (waitT * 5 ).times do |n|
      if test(?f, outfname )
        size = File.size( outfname )
        break if size > 1024
      end
      sleep(0.2)
    end

    if ! test(?f, outfname ) or File.size( outfname ) < 1024
      DBlog::sto("kill for retry #{pid}")
      begin
        Process.kill(:HUP, pid);
      rescue
      end
      raise ExecError
    end

    return pid
  end

  #
  # recpt1 の実行コマンドの生成
  #
  def makeCmd(
        ch, time,
        outfn: nil,
        b25:  nil,
        udp:  nil,
        addr: nil,
        port: nil,
        dev:  nil,
        lnb:  nil,
        sid:  nil,
        other: nil  )
    cmd = [ Recpt1_cmd ]
    cmd << "--b25" if b25 == true 
    cmd << "--udp" if udp != nil
    cmd += %W( --addr #{addr} )  if addr != nil
    cmd += %W( --port #{port} )  if port != nil
    cmd += %W( --lnb #{lnb} )  if lnb != nil
    if sid != nil
      if sid.class == Array
        cmd += %W( --sid #{sid.join(",")} )
      elsif sid.class == String or sid.class == Integer
        cmd += %W( --sid #{sid.to_s} )
      end
    end
    if dev != nil
      if Recpt1_cmd =~ /recdvb/
        dev = $1 if dev =~ /adapter(\d)/
      end
      cmd += %W( --device #{dev} )
    end
    if Recpt1_opt.class == Array
      cmd += Recpt1_opt
    elsif Recpt1_opt.class == String
      cmd << Recpt1_opt
    end

    raise "makeCmd() channel is nil" if ch == nil
    raise "makeCmd() time is nil" if time == nil

    ch2 = EpgAutoPatch.new.bsSlotAdj( ch )
    
    cmd += [ ch2.to_s, time.to_s ]
    cmd << outfn if outfn != nil

    return cmd
  end
end
