#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  mpv モニター
#

class MpvMonMain

  attr_reader   :data, :devs2
  
  def initialize(  )
    @data = {}
    @band    = %w( GR BSCS 3W )
    @prefix = "DeviceList"
    @devs = DeviceList_GR + DeviceList_BSCS
    @devs2 = []
      
    count = 0
    @band.each do |suffix|
      name = @prefix + "_" + suffix
      if Object.const_defined?( name ) == true
        ary = eval( name )
        if ary.class == Array
          ary.each do |dev|
            dev2 = File.basename( dev )
            @devs2 << dev2
            @data[ dev2 ] ||= MpvMonM.new( dev )
            @data[ dev2 ].addBand( suffix )
            @data[ dev2 ].set_count( count )
            count += 1
          end
        end
      end
    end

    @devs.each do |dev|
      unless FileTest.chardev?(dev)
        dev2 = File.basename( dev )
        @data[dev2].stat = :NotFond
      end
    end
    
  end

  #
  #  使用中のデバイスを検出
  #
  def chkDeviceStat()

    @devs2.each do |dev2|
      if @data[ dev2 ].stat != :NotFond
        @data[ dev2 ].stat = :OK
      end
    end

    lsof = Object.const_defined?(:Lsof_cmd) == true ? Lsof_cmd : "lsof"
    cmd = %W( #{lsof} +d /dev )
    IO.popen( cmd, "r") do |io|
      io.each_line do |line|
        dev = line.split.last
        if @devs.include?( dev )
          dev2 = File.basename( dev )
          @data[ dev2 ].stat = :Busy
        end
      end
    end
  end

  
  #
  #  空いている適当な device名を返す
  #
  def autoSel( chid )
    band = case chid
           when /^BS/ then Const::BS
           when /^CS/ then Const::CS
           when /^GR/ then Const::GR
           end

    chkDeviceStat()

    @devs2.each do |devfn|
      if @data[ devfn ].band[ band ] == true
        if @data[ devfn ].stat == :OK
          return devfn
        end
      end
    end
    nil
  end

   
end

class MpvMonM 

  attr_reader   :devfn, :devfnF, :band, :rec_pid, :mpv_pid, :phch, :chName, :prog_name, :prog_detail, :fifo, :selBand, :count
  attr_accessor :stat, :statS
  
  def initialize( dev )
    @devfn  = File.basename(dev)  # デバイスファイル名
    @devfnF = dev                 # デバイスファイル名(full)
    @band = {}                    # 使用可能なバンド :GR,:BS, :CS
    @rec_pid = nil                # recpt1 のpid
    @mpv_pid = nil                # mpv のpid
    @phch        = nil            # 現在の物理チャンネル
    @chName      = "-"            # 放送局名
    @prog_name   = "-"            # 番組名
    @prog_detail = "-"            # 番組概要
    @stat        = :OK            # 状態(シンボル :OK,:Busy,:NotFond)
    @statS       = "-"            # 状態(表示用)
    @fifo        = nil            # recpt1 -> mpv FIFO
    @selBand     = nil            # 選択中のバンド
    @count       = 0              # シリアル番号(udp port のオフセット)
    
    #attr_reader_All()
  end

  # #
  # # 自動 attr_reader
  # #
  # def attr_reader_All()
  #   instance_variables.each do |var|
  #     var2 = var.to_s.sub(/^@/,'')
  #     self.class.send(:define_method, var2 ) {  eval( var.to_s ) }
  #   end
  # end

  def set_count( n )
    @count = n
  end

  #
  #  使用可能なバンドを登録
  #
  def addBand( band )
    @band[ Const::GR ] = true  if band == "GR"
    if band == "BSCS"
      @band[ Const::BS ] = true  
      @band[ Const::CS ] = true
    end
    if band == "3W"
      @band[ Const::GR ] = true  
      @band[ Const::BS ] = true
      @band[ Const::CS ] = true
    end
  end

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
              STDOUT.puts outbuf
              STDOUT.flush
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
    phch = case data[:band]
           when Const::GR then data[:stinfo_tp].to_s
           when Const::BS then sprintf("%s_%s",data[:stinfo_tp], data[:stinfo_slot] )
           when Const::CS then data[:stinfo_tp].to_s
           end
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
  def play( chid)

    sleep(1) if stop()          # 起動中があれば停止

    # 物理チャンネル,svid の取得, 番組情報の取得
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

    cmd1 = %W( #{Recpt1_cmd} --b25 #{@phch} --sid #{@svid} --device #{@devfnF} )
    if RemoteMonitor == true
      port = UDPbasePort + @count
      cmd1 += %W( --udp --addr #{XServerName} --port #{port} 99999 )
      cmd2 = %W( ssh -t -t #{XServerName} env DISPLAY=:0 )
      cmd2 += MPlayer_cmd + %W( udp://#{RecHostName}:#{port}/ )
    else
      @fifo  = makeFifo( @devfn ) if @fifo == nil
      cmd1 += %W( 99999 #{@fifo} )
      cmd2 = MPlayer_cmd + %W( #{@fifo} )
    end
    cmd2.push( %Q(--title="#{@chName}" )) if MPlayer_cmd[0] =~ /mpv/
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



