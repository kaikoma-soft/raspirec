# coding: utf-8

#
#  raspirecTV.rb 関連
#

class Video

  attr_reader :recPid
  
  def initialize( serial = 0 )
    @port      = UDPbasePort + serial
    if RemoteMonitor == true
      @videoPort = "udp://#{RecHostName}:#{@port}/"
    else
      @videoPort = "udp://localhost:#{@port}/"
    end
    @ipc      = makeTmpFn( serial, "cmd" )  # mpv のコマンド入力
    @recPid   = nil
    @mpvpid   = nil
    @serial   = serial
    @nullP = File.open( "/dev/null","w+")
  end

  #
  #  中間(作業)ファイル名の作成
  #
  def makeTmpFn( serial, key = "fifo" )
    fn = sprintf("/tmp/raspirecTV_%03d.%s",serial, key)
    return fn
  end

  #
  #   socket にコマンド書き込み
  #
  def ipcSendMsg( fname, msg )
    dlog( msg )
    if RemoteMonitor == false
      s = UNIXSocket.new(fname)
      s.write(msg + "\n" )
      s.close
    else
      cmd = %W( ssh #{XServerName} socat -  #{fname} )
      dlog( cmd.join(" ") )
      Open3.popen3( *cmd ) do | stdin, o, e, t|
        stdin.puts( msg )
        stdin.close
      end
    end
  end

  #
  #  停止
  #
  def stop(  )
    [ @mpvPid, @recPid ].each do |pid|
      if pid != nil
        begin
          Process.kill( :KILL, pid )
          Process.waitpid( pid )
        rescue
        end
      end
    end
    @mpvPid = @recPid = nil
    
    File.unlink( @ipc )   if FileTest.socket?( @ipc )
  end

  
  #
  #  チャンネル変更
  #
  def chChange( chinfo, devfn, pageName )

    return false  if @recPid  == nil
    begin
      Process.kill( :HUP, @recPid )
    rescue
    end
    @recPid = nil
    Thread.new() do
      sleep( 0.5 )
      cmd = makeRecCmd( chinfo, devfn )
      dlog( cmd.join(" ") )
      opt = {}
      if $arg.d < 2
        opt = { :out => @nullP, :err => @nullP }
      end
      st = Time.now
      begin
        @recPid = spawn( *cmd, opt )
        Process.waitpid( @recPid )
      rescue
      end
      sa = Time.now - st
      if sa < 1.0
        msg = "#{Recpt1_cmd} の起動に失敗しました。"
        $queue.push($event.new(:msg, nil, msg ))
      end
    end
    sleep(1.0)
    ipcSendMsg( @ipc, "loadfile #{@videoPort}" )
    sleep(2.0)
    tmp = sprintf("\"%s : %s\"" ,pageName, chinfo.chname )
    ipcSendMsg( @ipc, "set title #{tmp}" )
    return true
  end



  #
  #   recpt1/recdvb のコマンド組み立て
  #
  def makeRecCmd( chinfo, devfn )
    ret = [ Recpt1_cmd ] + Recpt1_opt
    ret << "--b25" unless Recpt1_opt.join(" ") =~ /--b25/
    ret += case chinfo.band
           when Const::GR then
             %W( #{chinfo.phch} --sid hd )
           when Const::BS,Const::CS  then
             %W( #{chinfo.phch} --sid #{chinfo.svid} )
           end
    if Recpt1_cmd =~ /recpt1/
      ret += %W( --device #{devfn} )
    elsif Recpt1_cmd =~ /recdvb/
      if devfn =~ /adapter(\d)/
        num = $1
        ret += %W( --dev #{num} )
      end
    end
    ret += %W( 9999  --udp --port #{@port} --addr )
    if RemoteMonitor == false
      ret << "localhost"
    else
      ret << XServerName
    end

    return ret
  end

  #
  #  recdvb を起動
  #
  def play( chinfo, tun )

    reccmd = makeRecCmd( chinfo, tun.devfn )
    mpvcmd = []
    if RemoteMonitor == true
      mpvcmd = %W( ssh -t -t #{XServerName} env DISPLAY=:0 )
    end
    title = sprintf("--title=\"%s : %s\"" ,tun.name, chinfo.chname )
    mpvcmd << Mpv_cmd
    mpvcmd += Mpv_opt + [ "--no-terminal",
                          title,
                          "--input-ipc-server=" + @ipc,
                          @videoPort
                        ]
    opt = {}
    if $arg.d < 2
      opt = { :out => @nullP, :err => @nullP }
    end
      
    dlog( mpvcmd.join(" "))
    @mpvPid = spawn( *mpvcmd, opt) # exec mpv

    dlog( reccmd.join(" "))
    @recPid = spawn( *reccmd, opt ) # exec recpt1/dvb

    Thread.new(@recPid) do |pid|
      begin
        Process.waitpid( pid )
      rescue
      end
    end
  end

end
