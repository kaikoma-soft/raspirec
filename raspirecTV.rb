#!/usr/bin/ruby
# -*- coding: utf-8 -*-

#
#  mpvモニタの GUI独立版
#

require 'gtk3'
require 'thread'

=begin
TODO
 * 
=end

base = File.dirname( $0 )
$: << base + "/src"

RewriteConst = true

require 'require.rb'
require_relative 'src/TV/Video.rb'
require_relative 'src/TV/misc.rb'
require_relative 'src/TV/Arguments.rb'
require_relative 'src/lib/YamlWrap.rb'

$arg   = Arguments.new( ARGV )
#$queue = Array.new                       # event queue
$queueCh = Queue.new
$queueOt = Queue.new
$event = Struct.new(:cmd, :page, :val)   # queue に積む event Data
#DeviceChk.new.run

class RaspirecTV

  def initialize(  )

    @ws = {}                                  # ウィジェットの格納
    @ta = TunerArray.new                      # チューナー配列
    @ch2num = {}                              # chlist の保存
    @prog   = Prog.new()                      # 番組情報
    @chinfo = ChList.new()                    # チャンネル情報
    @video  = {}                              # video player
    @chList = @chinfo.getChList()             # チャンネル一覧
    @pto = nil                                # 番組表オプションの値
    @page2name = {}                           # page -> pageName 変換
    @dialog = false                            # ダイアログ中は ch 変更なし

    if $arg.epg == true
      getEPG()
    else
      if @chinfo.getChList.size == 0
        puts("Error: EPG 情報が取得できませんでした。")
        exit
      end
    
      setup()
      dataSetUp()
      worker()
      statCheckLoop()
      createGUI()
      cleanUp()
    end
  end

  #
  #  EPG 取得
  #
  def getEPG()
    $baseDir = File.join( BaseDir, "src" )
    $tunerArray = TunerArray.new
    $rec_pid = []

    GetEPG.new.start( Time.now.to_i + 600  ) 
  end
  
  #
  #  初期設定
  #
  def setup()
    Signal.trap( :HUP )  { dlog("signal :HUP") ; endParoc() }
    Signal.trap( :INT )  { dlog("signal :INT") ; endParoc() }
    Signal.trap( :TERM ) { dlog("signal :TERM") ; endParoc() }

    if RemoteMonitor == true
      if remoteCmdChk( :RaspirecTV_SOCAT ) == false
        puts("Error: RaspirecTV_SOCAT が不正です。")
        exit()
      end
      if remoteCmdChk( :Mpv_cmd ) == false
        puts("Error: Mpv_cmd が不正です。")
        exit()
      end
    end

    Commlib::makeSubDir()

  end

  #
  #  リモート側にコマンドが存在するか。string or シンボルで指定
  #
  def remoteCmdChk( sym )
    cmd = sym
    if sym.class == Symbol
      if Object.const_defined?( sym ) == true
        cmd = Object.const_get( sym )
      else
        return false
      end
    end
    cmd2 = %W( ssh #{XServerName} test -f #{cmd} && echo "OK" )
    dlog( cmd2.join(" ") )
    Open3.popen3( *cmd2 ) do | stin, sto, ste, t|
      sto.each_line do |line|
        if line =~ /OK/
          return true
        end
      end
    end
    return false
  end
    
  
  #
  #  デバイスの状態チェックの event 投入,  直近の録画予約時間のチェック
  #
  def statCheckLoop()
    
    Thread.start do
      sleep( 10 )
      reserve = DBreserve.new
      loop do 
        sleep( 5 )
        msg = nil
        DBaccess.new().open do |db|
          now = Time.now.to_i
          row = reserve.select( db,tend: now,limit: 1,order: "order by start" )
          row.each do |r|
            case r[:stat]
            when RsvConst::Normal then
              start2 = r[:start] - Start_margin
              if start2 < ( now + 600 )
                sa = start2 - now
                msg = sprintf("注意：次の録画開始まで、%d 分です。", sa / 60 )
              end
            when RsvConst::RecNow then
              msg = "注意：現在録画中です。"
            end
          end
        end
        if msg != nil
          $queueOt.push($event.new(:msg,nil,msg ))
        end
        sleep( 5 )
        $queueOt.push($event.new(:status,nil,nil))
        sleep( 170 )
      end
    end
  end

  #
  #  ボタンを連打されている間 wait する。
  #
  def queueWait( q )
    oldQsize = q.size
    sleep( 0.5 )
    loop do
      n = q.size
      break if n <= oldQsize
      sleep(1)
      oldQsize = n
    end
  end
  
  #
  #  event worker 
  #
  def worker()
    
    Thread.start do
      sleep(3)
      while qu = $queueCh.pop
        if qu.cmd == :chChange
          next if @dialog == true
          queueWait( $queueCh )
          $queueCh.clear()

          page = qu.page
          pageName = @page2name[page]
          tun      = qu.val
          para = getPara( page )
          chname   = para[:chname]
          if @video[pageName] != nil
            tmp = @chinfo.getPhCh( para[:chid] )
            if @video[pageName].chChange( tmp, tun.devfn, pageName ) == true
              statmesg( "チャンネル変更: #{chname}  #{tmp.phch}  #{tmp.svid}" )
            end
          end
          sleep(3)        # クールタイム
        end
      end
    end

    Thread.start do
      sleep(3)
      while resource = $queueOt.pop
        page = resource.page
        pageName = @page2name[ page ]
        para = getPara( page )
        case resource.cmd
        when :mpvOpen then
          tun      = resource.val
          if @video[pageName] == nil
            @video[pageName] = Video.new(para[:tun].serial)
          end
          tmp = @chinfo.getPhCh( para[:chid] )
          @video[pageName].play( tmp, tun )
          statmesg( "起動: #{pageName}" )
        when :mpvStop then
          if @video[pageName] != nil
            @video[pageName].stop( )
            statmesg( "停止: #{pageName}" )
          end
        when :msg then
          statmesg( resource.val )
        when :status then
          @ta.chkDeviceStat()
          statUpdate()
        end
      end
    end
    
    Thread.start do
      sleep(3)
      while true
        $queueOt.push($event.new(:status,nil,nil))
        sleep(10)
      end
    end
  end

  #
  #  状態の文字列を更新
  #
  def statUpdate()
    markup = "<span foreground=\"#D82020\">%s</span>"
    @ta.each_with_index do |t1,n|
      pageName = t1.name
      tab = " #{pageName} "
      stat = "使用可"
      sensitive = true
      if t1.stat != :OK
        if @video[pageName] != nil and @video[pageName].recPid != nil
          stat = sprintf( markup, "使用中")
        else
          sensitive = false
          stat = sprintf( markup, "使用中(他)")
        end
        tab  = sprintf( markup, tab )
      end
      @ws[pageName][:stat].set_markup(stat)
      @ws[pageName][:mpv].sensitive= sensitive

      child = @ws[pageName][:tab]
      label = Gtk::Label.new( )
      label.set_markup(tab)
      @ws[:note].set_tab_label(child, label )
    end
  end
  
  def dataSetUp()

    # BSCS を BS と CS に分離
    @ta.delete_if{|v| v.devfn == nil }
    @ta.each do |t1|
      t1.band[ Const::BS ] = t1.band[ Const::BSCS ]
      t1.band[ Const::CS ] = t1.band[ Const::BSCS ]
      t1.band.delete( Const::BSCS )
      t1.band.delete( :short )
    end
    
    # バンドと放送局の初期値を決定
    @ta.each do |t1|
      if t1.devfn != nil
        t1.band.each_pair do |k,v|
          if v == true
            t1.selBand = k
            if t1.selBand == Const::GR
              ( t1.chName, t1.chid ) = @chList[ t1.selBand ].first
            else
              t1.selBand = Const::BS
              ( t1.chName, t1.chid ) = @chList[ Const::BS ].first
            end
            break
          end
        end
      end
    end
  end

  #
  #  終了
  #
  def endParoc()
    cleanUp()
    exit!()
  end
  
  #
  #   終了時の後始末
  #
  def cleanUp()
    @video.each_pair do |k,v|
      v.stop( )
    end
  end
  
  #
  #  GUI 作成
  #
  def createGUI()

    window = Gtk::Window.new
    window.name = "main window"
    window.signal_connect("destroy"){ "destroy"; cleanUp(); Gtk.main_quit  }

    if $arg.font != nil         # font の変更
      Gtk::Settings.default.gtk_font_name= $arg.font
    end
    
    vbox1 = Gtk::Box.new(:vertical, 0 ) 
    window.add( vbox1 )

    @ws[:note] = Gtk::Notebook.new( )
    @ws[:note].margin = 5
    vbox1.pack_start(@ws[:note], :expand => true, :fill => true, :padding => 5)
  
    @ws[:note].scrollable = true
    @ws[:note].signal_connect("switch-page") do
      $queueOt.push($event.new(:status,nil,nil))
    end

    def attach( pw, lw, rw, y )
      grid_attach( pw, lw, rw, y )
    end

    def table_attach( pw, lw, rw, y )
      pw.attach( lw, 0, 1, y, y+1 )
      pw.attach( rw, 1, 2, y, y+1 )
    end

    def grid_attach( pw, lw, rw, y )
      pw.attach( lw, 0, y, 1, 1 ) # 左
      pw.attach( rw, 1, y, 1, 1 ) # 右
    end
    
    @ta.each_with_index do |t1,n|
      pageName = t1.name
      @ws[pageName] ||= {}
      page = t1.serial - 1
      @page2name[ page ] = pageName

      ######  チューナー選択 TAB ########
      label =  Gtk::Label.new( " #{pageName} " )
      
      tbl = Gtk::Grid.new
      tbl.row_spacing    = 10
      tbl.column_spacing = 10
      tbl.margin_top     = 20
      tbl.margin_bottom  = 20
      
      @ws[:note].append_page(tbl, label )
      @ws[pageName][:tab] = tbl
      
      ######  デバイス  ########
      y = 0
      label1 = Gtk::Label.new("デバイス")

      hbox = Gtk::Box.new(:horizontal, 0 )
      label2 = Gtk::Label.new( t1.devfn )
      label2.set_xalign(0)
      hbox.pack_start( label2 )
      
      label3 = Gtk::Label.new( "-" )
      @ws[pageName][:stat] = label3
      hbox.pack_start( label3, :padding => 10 )

      attach( tbl, label1, hbox, y )
      
      ######  ディスプレイ On/Off  ########
      y += 1
      label = Gtk::Label.new( "ディスプレイ")
      bon = Gtk::ToggleButton.new( :label => "On/Off")
      @ws[pageName][:mpv] = bon
      hbox = Gtk::Box.new(:horizontal, 0 )
      hbox.pack_start(bon, :padding => 10)
      bon.signal_connect("toggled") do |bon|
        if bon.active? == true
          $queueOt.push($event.new(:mpvOpen,page, t1))
        else
          $queueOt.push($event.new(:mpvStop,page, t1))
        end
      end
      attach( tbl, label, hbox, y )

      ######  放送局選択  ########
      y += 1
      label = Gtk::Label.new("選局")
      hbox = Gtk::Box.new(:horizontal, 0)

      cb = Gtk::ComboBoxText.new
      @ws[pageName][:cb] = cb
      cb.set_width_request(250)
      setChList( t1, cb )
      cb.signal_connect("changed") do |cb|
        para = getPara( page )
        tmp = @prog.getData( para[:chid] )
        tmp = tmp != nil ? tmp.prog_name : "-"
        @ws[pageName][:progname].set_text( tmp )
        
        $queueCh.push($event.new(:chChange, page, t1))
      end
      attach( tbl, label, hbox, y )
      
      hbox.pack_start(@ws[pageName][:cb], :padding => 10)

      bon = Gtk::Button.new( :label => "↑")
      hbox.pack_start( bon, :padding => 5)
      bon.signal_connect("clicked") do
        upDown( t1, cb, :up )
      end
      bon = Gtk::Button.new( :label => "↓")
      hbox.pack_start( bon, :padding => 5)
      bon.signal_connect("clicked") do
        upDown( t1, cb, :down )
      end
     
      if $arg.round != nil
        bon = Gtk::ToggleButton.new( :label => "巡回")
        @ws[pageName][:round] = bon
        hbox.pack_start( bon, :padding => 5)
        bon.signal_connect("toggled") do |bon|
          if bon.active? == true
            @ws[pageName][:roundTH] = Thread.new do
              loop do
                upDown( t1, cb, :down )
                sleep( $arg.round )
              end
            end
          else
            if @ws[pageName][:roundTH] != nil
              @ws[pageName][:roundTH].kill
              @ws[pageName][:roundTH] = nil
            end
          end
        end
      end
      
      ######  番組名  ########
      y += 1
      label1 = Gtk::Label.new("番組名")
      
      tmp = @prog.getData( t1.chid )
      tmp = tmp == nil ? "-" : tmp.prog_name

      label2 = Gtk::Label.new( tmp )
      label2.set_xalign(0)
      label2.set_max_width_chars(25)
      label2.line_wrap = true
      label2.set_hexpand( true )
      @ws[pageName][:progname] = label2

      attach( tbl, label1, label2, y )

    end

    @ws[:sb] = Gtk::Statusbar.new
    vbox1.pack_start( @ws[:sb], :padding => 1)
    
    hbox = Gtk::Box.new(:horizontal, 0 )
    vbox1.pack_start(hbox, :padding => 1)

    ######  番組概要  ########
    bon3 = Gtk::Button.new(:label => "番組概要")
    hbox.pack_start(bon3, :expand => true, :fill => true, :padding => 10)
    bon3.signal_connect("clicked") do
      para = getPara()
      prog_detail( para, window )
    end

    ######  ミニ番組表  ########
    bon3 = Gtk::Button.new( :label => "ミニ番組表")
    hbox.pack_start(bon3, :expand => true, :fill => true, :padding => 10)
    bon3.signal_connect("clicked") do
      page = @ws[:note].page
      miniPrgTbl( @ta[ page ].name, window )
    end
    
    ######  番組表  ########
    bon3 = Gtk::Button.new( :label => "番組表")
    hbox.pack_start(bon3, :expand => true, :fill => true, :padding => 10)
    bon3.signal_connect("clicked") do
      page = @ws[:note].page
      prgTbl( @ta[ page ].name, window )
    end
    
    ######  終了  ########
    bon3 = Gtk::Button.new( :label => "終了")
    hbox.pack_start(bon3, :expand => true, :fill => true, :padding => 10)
    bon3.signal_connect("clicked") do
      window.destroy
      Gtk.main_quit
      exit!()
    end

    if $arg.w != nil and $arg.h != nil
      window.set_size_request( $arg.w, $arg.h)
    end
    if $arg.x != nil and $arg.y != nil
      window.move( $arg.x, $arg.y )
    end
    window.show_all

    while true
      Gtk.main
      sleep( 0.1 )
    end

  end

  
  #
  #  パラメータの取得
  #
  def getPara( page = nil )
    ret = {}
    page = @ws[:note].page if page == nil
    ret[:page] = page
    ret[:tun ] = @ta[page]
    name = ret[:tun].name
    ret[:chname ] = chName = @ws[name][:cb].active_text
    @chList.keys.each do |band|
      @chList[band].each_pair do |k,v|
        if k == chName
          ret[:chid] = v
          ret[:band] = band
        end
      end
    end

    return ret
  end
  
  #
  # status bar メッセージ表示
  #
  def statmesg( str )
    context_id = @ws[:sb].get_context_id("Statusbar")
    @ws[:sb].push(context_id, str )
  end


  #
  #  放送局のリストを設定
  #
  def setChList( tun, cb )
    count = 0
    tun.band.each_pair do |band,v|
      if v == true and @chList[ band ] != nil
        count += @chList[ band ].size 
      end
    end
    wrap = ( count / 15 ).round
    cb.wrap_width = wrap
    
    count = 0
    @ch2num[tun.name] ||= []
    tun.band.each_pair do |band,v|
      if v == true
        if count > 0 and wrap > 0
          n = ( count % wrap ) == 0 ? 0 : ( wrap - ( count % wrap ))
          ( wrap + n ).times do
            cb.append_text( "-" ) # セパレータ
            @ch2num[tun.name] << "-"
          end
        end
        count = 0
        if @chList[ band ] != nil
          @chList[ band ].each_pair do |k,v|
            cb.append_text( k )
            count += 1
            @ch2num[tun.name] << k
          end
        end
      end
    end

    cb.set_row_separator_func do |model, iter|
      val = model.get_value(iter, 0)
      cb.set_active_iter(iter)  if val == tun.chName
      val == "-"
    end
  end
      
  
  
  #
  #  チャンネル 上下のボタン
  #
  def upDown( tun, cb, direction )
    ch = cb.active_text
    n = @ch2num[tun.name].index( ch )
    if n != nil
      if direction == :down
        n += 1
        while @ch2num[tun.name][n] == "-" do
          n += 1
        end
      else
        n -= 1
        while @ch2num[tun.name][n] == "-" do
          n -= 1
        end
      end
      n = @ch2num[tun.name].size - 1 if n < 0 
      n = 0 if @ch2num[tun.name].size <= n

      cb.set_active( n )
    end

  end


  #
  #  番組概要 ダイアログ
  #
  def prog_detail( para, window )
    prog_detail = @prog.getDetail( para[:chid] )

    d = Gtk::Dialog.new( :title => "番組概要",
                         :parent => window,
                         :flags => [:modal ],
                         :buttons => nil)
    
    @dialog = true

    sw = Gtk::ScrolledWindow.new
    sw.set_policy(:automatic, :automatic)
    sw.set_size_request(600, 400)
    
    text = Gtk::TextView.new
    text.set_editable( false )
    text.set_wrap_mode( :char )
    text.buffer.set_text( prog_detail )

    sw.add( text )
    d.child.add(sw)
    d.add_buttons(["閉じる", 1])
    d.show_all
    d.run
    d.destroy
    @dialog = false
  end
  



  #
  #   raspirec 番組表の呼び出し
  #
  def prgTbl( pageName, window )
    para = getPara()
    band = para[:band]
    chname = para[:chname]
    @pto = PTOption.new if @pto == nil
    page_limit = @pto.sp
    progdata = @prog.data
    pagenum = 0
    if @chList[band] != nil     # 番組表のページ計算
      n = 0
      @chList[band].each_pair do |k,v|
        next if progdata[v] == nil
        if k == chname
          pagenum = ( n / page_limit )
          break
        end
        n += 1
      end
    end

    if Commlib::executable?( Browser_cmd ) == false
      statmesg( "Error: Browser_cmd の値が不正です。( #{Browser_cmd})" )
      return
    end
    
    null = File.open("/dev/null","w+")
    page = sprintf("%s%d",band,pagenum )
    cmd = Browser_cmd + " http://localhost:#{Http_port}/prg_tbl/#{page}"
    pid = spawn( cmd,  :out => null, :err => null )
    Thread.new(pid) do |pid|
      begin
        Process.waitpid( pid )
        null.close
      rescue
      end
    end
  end

  #
  #  ミニ番組表 ダイアログ
  #
  def miniPrgTbl( pageName, window )
    para = getPara()
    band = para[:band]
    progdata = @prog.data

    d = Gtk::Dialog.new( :title => "ミニ番組表",
                         :parent => window,
                         :flags => [:modal ],
                         :buttons => [["閉じる", :ok]] )
    d.set_size_request(600, 300)
    @dialog = true

    list = []
    [ Const::GR, Const::BS, Const::CS ].each do |band|
      if para[:tun].band[ band ] == true
        list += @chList[ band ].map {|v| v.to_a }
      end
    end

    treestore = Gtk::TreeStore.new(String, String )
    list.each do |tmp|
      chname, chid = tmp
      parent = treestore.append(nil)
      parent[0] = chname
      parent[1] = progdata[chid] == nil ? "-" : progdata[chid].prog_name
    end
    view = Gtk::TreeView.new(treestore)
    
    renderer = Gtk::CellRendererText.new
    col = Gtk::TreeViewColumn.new("局名", renderer, :text => 0)
    view.append_column(col)
    renderer = Gtk::CellRendererText.new
    col = Gtk::TreeViewColumn.new("番組名", renderer, :text => 1)
    view.append_column(col)

    view.signal_connect("row-activated") do |view, path, column|
      if iter = view.model.get_iter(path)
        if ( n = @ch2num[pageName].index( iter[0] )) != nil
          @ws[pageName][:cb].set_active( n )
          d.destroy
          d = nil
          @dialog = false
        end
      end
    end
    
    sw = Gtk::ScrolledWindow.new
    sw.add_with_viewport(view)
    sw.set_size_request(600, 300)
    
    d.child.add(sw)
    d.show_all

    response = d.run
    if response == :ok
      begin
        d.destroy if d != nil
      rescue
        dlog( "destroy error" )
      end
    end

    @dialog = false
  end
  
end



RaspirecTV.new()

