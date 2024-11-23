# coding: utf-8

require 'sinatra'
require 'slim'

base = File.dirname( $0 )
[ ".", "..","src", base ].each do |dir|
  if test( ?f, dir + "/require.rb")
    $: << dir
    $baseDir = dir
  end
end

RewriteConst = true
require 'require.rb'


$debug = Debug
ARGV.each do |arg|
  $debug = true if arg == "--debug"
end

reopenSTD( StdoutH, StderrH )

File.open( HttpdPidFile, "w") do |fp|
  fp.puts( Process.pid  )
end

$childPid = {}

#
#  :CHLD のハンドラ
#
def childWait()
  #DBlog::sto("childWait()")
  $childPid.keys.each do |k|
    if $childPid[k] == true
      begin
        if Process.waitpid( k, Process::WNOHANG ) != nil
          DBlog::sto("httpd:childWait() pid=#{k} Terminated") # 成仏
          $childPid.delete(k)
        end
      rescue Errno::ECHILD
        $childPid.delete(k)
      end
    end
  end
end

$tunerArray = TunerArray.new

#
#  モニタの停止
#
def moni_stop( txt )
  n = 0
  if $tunerArray != nil
    n += $tunerArray.stop()
  end
  n +=1 if MonitorM.new.osoji() == true
  
  DBlog::info(nil, txt ) if n > 0
end

#
#  httpd 終了処理
#
def endParoc()
  DBlog::sto( "httpd endParoc() #{$httpd_pid}" )
  moni_stop( "終了処理で、モニタを停止しました。")
  Sinatra::Application.quit!
end

#
#  録画開始(timer からのsignal)に伴うモニタ終了処理
#
def sigUsr1()
  DBlog::stoD( "sigUsr1()" )
  moni_stop( "録画開始の為、モニタを停止しました。" )
end

#
#   初期化
#
Signal.trap( :CHLD ) { childWait() }
Signal.trap( :HUP )  { DBlog::stoD("httpd :HUP") ; endParoc() }
Signal.trap( :INT )  { DBlog::stoD("httpd :INT") ; endParoc() }
Signal.trap( :TERM ) { DBlog::stoD("httpd :TERM") ; endParoc() }
Signal.trap( :USR1 ) { DBlog::stoD("httpd :USR1") ; sigUsr1() }

DBlog::info(nil,"httpd_main start #{Commlib::getVer()}")

enable :sessions
set :server, "webrick"
set :slim, pretty: true
set :sass, content_type: 'text/css', charset: 'utf-8'
enable :reloader

before do
  @band = "GR"
  @day  = nil
  @time = nil
  @ch   = "ch"
  DBlog::sto("#{request.request_method} #{request.path_info} <#{request.referrer}>" ) if $debug == true
end


#
#   Top
#
get '/' do
  slim :top
end


#
#  番組表
#
def prg_tbl( band = nil ,day = nil, time = nil )
  @title = "番組表"
  session[:band] = @band = band
  session[:day]  = @day  = day
  session[:time] = @time = time
  session[:fa_type] = :none
  slim :prg_tbl
end

get '/prg_tbl/*/*/*' do |band,day,time| prg_tbl( band,day,time ) end
get '/prg_tbl/*'     do |band|          prg_tbl( band ) end
get '/prg_tbl'       do                prg_tbl( ) end



#
#  番組表(局ごと)
#
get '/ch_tbl/*' do |ch|
  @ch = ch
  if @params["skip"] != nil
    ChannelM.new.set( @ch, @params["skip"] )
  end
  slim :ch_tbl
end

get '/ch_tbl_list' do
  slim :ch_tbl_list
end

post '/ch_info/del/*' do |chid|
  @chid = chid
  #ChannelM.new.delete( @chid )
  ChannelM.new.invalid( @chid )
end
get '/ch_info' do
  slim :ch_info
end



#
#  番組詳細のダイアログ
#
get '/prg_dialog/*' do |pid|
  @pid = pid
  session[:from] = request.referrer
  slim :prg_dialog , layout: false
end

#
#  option のダイアログ
#
post '/opt_dialog/save' do
  pto = PTOption.new()
  pto.save( @params )
end

get '/opt_dialog' do
  session[:from] = request.referrer
  slim :opt_dialog , layout: false
end



get '/search/*/*' do |mode,id|  # 番組検索(既存)
  case mode
  when "pro" then @proid = id ; @filid = nil
  when "fil" then @filid = id ; @proid = nil
  end
  slim :search
end
get '/search' do                # 番組検索(新規)
  @proid = nil
  slim :search
end

# フィルター or 自動予約の追加
post '/sea_add/*' do |type|             
  fp = FilterM.new(@params)
  type2 = type == "fil" ? :filter : :autoRsv
  id = fp.add( @params, type2 )
  redirect "/fil_res_dsp/#{id}"
end

post '/sea_aut_add' do          #
  fp = FilterM.new(@params)
  id = fp.add( @params, :autoRsv )
  redirect "/fil_res_dsp/#{id}"
end

#
#  filtering 番組表
#
get '/fil_listD/*' do |id|
  @id = id
  slim :fil_listD, layout: false
end

get '/fil_list' do              # フィルター一覧
  session[:fa_type] = :filter
  slim :fil_list
end


post '/fil_del/*' do |id|       # フィルター削除
  @id = id
  fp = FilterM.new(@params)
  fp.del(id)

  case session[:fa_type]        # 元のページに戻る
  when :autoRsv  then  redirect "/aut_rsv_list",301
  when :filter   then  redirect "/fil_list",301
  when :rsv_list then  redirect "/rsv_list",301
  when :rsv_list_old then  redirect "/rsv_list_old",301
  end
end

post '/fil_testrun' do          # フィルター テスト実行
  slim :fil_testrun, layout: false
end

get '/fil_res_dsp/*' do |id|    # フィルター結果表示
  @id = id
  if session[:from] =~ /fil_res_dsp/
    session[:fa_type] = :filter
  end
  slim :fil_res_dsp
end



#
#   自動予約一覧
#
get '/aut_rsv_list'   do
  session[:fa_type] = :autoRsv
  slim :fil_list
end


#
#  コントロールパネル
#
def control( act ,arg = nil )
  cp = Control.new()
  case act
  when "logdel"  then cp.logdel( arg )
  when "tsft"    then cp.tsft( arg )
  when "epg"     then cp.epg()
  when "filupd"  then cp.filupd()
  when "restart" then cp.restart()
  when "stop"    then cp.stop()
  when "fcopy"   then cp.fcopy( @params )
  when "logRote" then cp.logrote()
  else DBlog::sto("control() not found #{act}")
  end
  redirect "/",301
end
get  '/control/*/*' do |act,arg| control( act ,arg )  end
get  '/control/*'   do |act|     control( act )  end
post '/control/*'   do |act|     control( act )  end
get  '/control'     do
  slim :control
end


#
#  カテゴリ対色
#
get '/cate_color' do
  slim :cate_color
end

#
# 予約削除,内容修正
#
post '/rsv_list/*/*' do |mode,rid|
  rp = Reservation.new(@params)
  case mode
  when "Del" then
    rp.del(rid)
  when "Mod" then
    rp.mod(rid)
  when "Stop" then
    rp.stop(rid)
  end
end

#
#  録画予約一覧
#
get '/rsv_list' do
  session[:fa_type] = :rsv_list
  slim :rsv_list
end

get '/rsv_list_D/*' do |rid|
  @rid = rid
  slim :rsv_list_D, layout: false
end
get '/rsv_tbl' do
  slim :rsv_tbl
end
get '/rsv_tbl/*/*' do |day,time|
  @title = "番組表"
  session[:day]  = @day  = day
  session[:time] = @time = time
  slim :rsv_tbl
end


def rsv_list_old(page)
  session[:fa_type] = :rsv_list_old
  @page = page
  slim :rsv_list_old
end
get  '/rsv_list_old/*' do |page| rsv_list_old(page) end
get  '/rsv_list_old'   do        rsv_list_old(nil)  end
post '/rsv_list_old'   do        rsv_list_old(nil)  end



get '/pack_chk_view/*' do |rid|
  @rid = rid
  slim :pack_chk_view, layout: false
end



#
#  録画予約確認
#
post '/rsv_conf' do
  slim :rsv_conf, layout: false
end

#
#  録画予約確認 ボタンを押した後
#
post  '/rsv/add' do
  if @params["proid"] != nil
    Reservation.new(@params).add(@params["proid"])
  end
  url = makePrgtblUrl( session )
  redirect url,301
end


#
#   HLS モニター
#
get '/monitor' do
  slim :monitor
end

get '/monitor/*/*' do |type,arg|
  MonitorM.new.start( type,arg )
end

configure do
  mime_type :m3u8, 'application/x-mpegURL'
  mime_type :ts,   'video/MP2T'
end

get '/stream/*' do |fname|
  if fname == Const::PlayListFname
    FileUtils.touch( DataDir + "/stream/m3u8.touch" )
  end
  path = DataDir + "/stream/" + fname
  type = case fname
         when /\.m3u8$/ then :m3u8
         when /\.ts$/   then :ts
         else nil
         end
  if test( ?f, path ) and type != nil
    send_file path, :status => 201, :type => type
  else
    status 404
  end
end


#
#  mpv モニター
#
def mpv_mon_func( tunNum ,cmd, chid )
  @tunNum, @cmd, @chid = tunNum, cmd, chid

  rdflag = false
  if $tunerArray != nil and tunNum != nil
    tunNum = $tunerArray.autoSel(chid)  if tunNum == "auto"
    if tunNum != nil
      case cmd
      when "ch"   then  $tunerArray.play( tunNum.to_i, chid ) ; rdFlag = true
      when "stop" then  $tunerArray.stop( tunNum.to_i )       ; rdFlag = true
      end
    else
      @tunNum = nil
      @cmd   = "disp"
    end
  end

  if rdFlag == true
    sleep(0.5)
    url = "/mpv_mon/#{tunNum}/disp"
    redirect to(url)
  else
    slim :mpv_mon
  end
end

get  '/mpv_mon/*/*/*' do |tunNum,cmd,chid| mpv_mon_func( tunNum,cmd,chid ) end
get  '/mpv_mon/*/*'   do |tunNum,cmd|      mpv_mon_func( tunNum,cmd, nil ) end
get  '/mpv_mon'       do                   mpv_mon_func( 1, "disp",nil)    end


#
#   log
#
def log_view_func(level,page)
  @level, @page = level, page
  slim :log_view
end
get '/log_view/*/*' do |level,page|  log_view_func(level,page) end
get '/log_view/*'   do |level|       log_view_func(level,1 )   end
get '/log_view'     do               log_view_func( nil,1 )    end


get '/config' do
  slim :config
end

get '/help' do
  slim :help
end

get '/test' do
  slim :test , layout: false
end

#
#  sinatora restart
#
get '/kill' do
  @title = 'kill'
  Thread.new do
    sleep( 0.1 )
    Process.kill( :HUP, $$ )
  end
  slim :kill
end

#
#  httpd,timer restart
#
get '/kill2' do
  @title = 'kill'
  control = Control.new
  Thread.new do
    sleep( 0.1 )
    control.restart()
  end
  slim :kill
end

#
#   CSS
#
get '/*.css' do |fn|
  case fn
  when "style"
    sass :style, content_type: 'text/css', :charset => 'utf-8'
  when "overlaid"
    sass :overlaid
  when "nav"
    sass :nav
  end
end

after do
  cache_control :no_cache
end

