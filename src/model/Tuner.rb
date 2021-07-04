# coding: utf-8

#
#  
#
class Tuner
  attr_reader   :name, :band, :num
  attr_accessor :data, :used, :devfn, :serial, :selBand, :chName, :chid
  attr_reader   :rec_pid, :mpv_pid, :phch, :prog_name, :prog_detail, :fifo
  attr_accessor :stat, :statS

  def initialize( name, gr, bscs, short )
    @name = name
    @data = []
    @band = { Const::GR => gr, Const::BSCS => bscs, :short => short }
    @num  = { Const::GR => 0, Const::BSCS => 0, :short => 0 }
    @used = false             # 使用中フラグ
    @devfn = nil              # device name
    @serial = nil             # シリアル番号(udp port のオフセット)

    @rec_pid = nil                # recpt1 のpid
    @mpv_pid = nil                # mpv のpid
    @phch        = nil            # 現在の物理チャンネル
    @chName      = "-"            # 放送局名
    @chid        = nil            # chid
    @prog_name   = "-"            # 番組名
    @prog_detail = "-"            # 番組概要
    @stat        = :OK            # 状態(シンボル :OK,:Busy,:NotFond)
    @statS       = "-"            # 状態(表示用)
    @fifo        = nil            # recpt1 -> mpv FIFO
    @selBand     = nil            # 選択中のバンド
    
  end

  def addData( data )
    @data << data
    sortS()
  end

  #
  #  開始時間で sort
  #
  def sortS()
    @data.sort! do |a,b|
      a[:start] <=> b[:start]
    end
  end
  

  ##########################################

  #
  #   デバイスの状態をチェック
  #
  def getStatStr()

    @statS = case  @stat
             when :NotFond then "使用不可(not exist)"
             when :OK      then "使用可"
             when :Busy    then @rec_pid != nil ? "使用中" : "使用不可(busy)"
             end
    return @statS
  end

  def cmdStart( cmd )
    bsize = 1024
    outbuf = "x" * bsize
    pid = nil
    Thread.new do
      Open3.popen2e( *cmd ) do |sin, out, wait|
        pid = wait.pid
        begin
          while out.eof? == false
            IO.select([out]).flatten.compact.each do |io|
              io.read_nonblock( bsize, outbuf )
              #STDOUT.puts outbuf
              #STDOUT.flush
              DBlog::sto( outbuf.chomp )
            end
          end
        rescue EOFError,Errno::EPIPE
          p $!
        rescue => e
          p $!
          p e.backtrace
        end
      end
      #pp "Thread end #{pid}"
    end

    10.times do |n|
      return pid if pid != nil
      sleep(1)
    end
    return nil
  end


  #
  #  fifo を作成して名前を返す。
  #
  def makeFifo( kw = "" )
    1.upto(999) do |n|
      fn = sprintf("/tmp/raspirec_%s_%03d.fifo",kw,n)
      unless FileTest.exist?( fn )
        File.mkfifo( fn )
        return fn
      end
    end
    nil
  end


  #
  #  recpt1 の物理選局
  #
  def makePhch( data )
    phch = Commlib::makePhCh( data )
    svid = data[:svid].to_s

    return [ phch, svid, data[:band] ]
  end

  def procKill( pid )
    if pid != nil
      Thread.new do
        begin
          Process.kill( :HUP, pid )
          sleep(1)
          Process.kill( :KILL, pid )
        rescue Errno::ESRCH
        end
      end
    end
    nil
  end


  #
  #  再生
  #
  def play( chid, prgInfo = true )

    sleep(1) if stop()          # 起動中があれば停止

    # 物理チャンネル,svid の取得, 番組情報の取得
    if prgInfo == true
      channel = DBchannel.new
      programs = DBprograms.new
      DBaccess.new().open do |db|
        db.transaction do
          row = channel.select( db, chid: chid )
          if row != nil and row.size > 0
            ( @phch, @svid, @selBand ) = makePhch( row[0] )
            @chName = row[0][:name]
          end
          now = Time.now.to_i
          row = programs.selectSP( db, chid: chid, tstart: now, tend: now )
          if row != nil and row.size > 0
            @prog_name = row[0][:title]
            @prog_detail = row[0][:detail]
          end
        end
      end
    end

    cmd1 = %W( #{Recpt1_cmd} --b25 #{@phch} --sid #{@svid}  )
    if Recpt1_cmd =~ /recpt1/
      cmd1 += [ "--device",@devfn ]
    elsif Recpt1_cmd =~ /recdvb/
      if @devfn =~ /adapter(\d)/
        num = $1
        cmd1 += [ "--dev", num ]
      end
    end
      
    if RemoteMonitor == true
      port = UDPbasePort + @serial
      cmd1 += %W( --udp --addr #{XServerName} --port #{port} 99999 )
      cmd2 = %W( ssh -t -t #{XServerName} env DISPLAY=:0 )
      cmd2 += [ Mpv_cmd ] + Mpv_opt + %W( udp://#{RecHostName}:#{port}/ )
    else
      @fifo  = makeFifo( @serial ) if @fifo == nil
      cmd1 += %W( 99999 #{@fifo} )
      cmd2 = [ Mpv_cmd ] + Mpv_opt + %W( #{@fifo} )
    end
    cmd2.push( %Q(--title="#{@chName}" )) if Mpv_cmd =~ /mpv/
    
    @rec_pid = cmdStart( cmd1 )
    @mpv_pid = cmdStart( cmd2 )
  end

  #
  #   停止
  #
  def stop()
    ret = @rec_pid != nil ? true : false

    @rec_pid = procKill( @rec_pid )
    @mpv_pid = procKill( @mpv_pid )
    if @fifo != nil and  FileTest.exist?( @fifo )
      File.unlink( @fifo )
      @fifo = nil
    end
    @phch   =  @svid =  @selBand = nil
    @chName = @prog_name = @prog_detail = "-"
    @stat   = :OK

    return ret
  end

end
