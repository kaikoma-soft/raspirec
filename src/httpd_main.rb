# coding: utf-8

require 'sinatra'
require 'sinatra/reloader'
require 'slim'

base = File.dirname( $0 )
[ ".", "..","src", base ].each do |dir|
  if test( ?f, dir + "/require.rb")
    $: << dir
  end
end

require 'require.rb'


$debug = Debug
ARGV.each do |arg|
  $debug = true if arg == "--debug"
end

reopenSTD( StdoutH, StderrH )

File.open( HttpdPidFile, "w") do |fp|
  fp.puts( Process.pid  )
end


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
get '/prg_tbl/*/*/*' do |band,day,time|
  @title = "番組表"
  session[:band] = @band = band
  session[:day]  = @day  = day
  session[:time] = @time = time
  session[:from] = "/prg_tbl/#{band}/#{day}/#{time}"
  slim :prg_tbl
end

get '/prg_tbl/*' do |band|
  @title = "番組表"
  session[:band] = @band = band
  session[:day]  = @day  = nil
  session[:time] = @time = nil
  session[:from] = "/prg_tbl/#{band}"
  session[:fa_type] = :none

  slim :prg_tbl
end

get '/prg_tbl' do
  session[:band] = nil
  session[:day]  = nil
  session[:time] = nil
  session[:from] = nil
  slim :prg_tbl
end

get '/ch_tbl/*' do |ch|
  @ch = ch
  slim :ch_tbl
end

get '/ch_tbl_list' do
  slim :ch_tbl_list
end


def fil_dispatch()
  if session[:fa_type] == :filter
    redirect "/fil_list",301
  else
    redirect "/aut_rsv_list",301
  end
end



#
#  番組詳細のダイアログ
#
get '/prg_dialog/*' do |pid|
  @pid = pid
  session[:from] = request.referrer
  slim :prg_dialog , layout: false
end


get '/search/*/*' do |mode,id|             #
  case mode
  when "pro" then @proid = id ; @filid = nil
  when "fil" then @filid = id ; @proid = nil
  end
  slim :search
end
get '/search' do              #
  @proid = nil
  slim :search
end
post '/sea_add/*' do |type|             #
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
get '/fil_list' do              # フィルター一覧
  session[:fa_type] = :filter
  slim :fil_list
end


post '/fil_del/*' do |id|       # フィルター削除
  @id = id
  fp = FilterM.new(@params)
  fp.del(id)
  redirect "/fil_list",301
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
#   自動予約
#
get '/aut_rsv_list' do          # 自動予約一覧;
  session[:fa_type] = :autoRsv
  slim :fil_list
end


#
#  コントロールパネル
#
get '/control/*/*' do |act,arg|
  cp = Control.new()
  case act
  when "logdel" then cp.logdel( arg )
  when "tsft"   then cp.tsft( arg )
  end
  redirect "/",301
  #slim :control
end
get '/control/*' do |act|
  cp = Control.new()
  case act
  when "epg"     then cp.epg()
  when "filupd"  then cp.filupd()
  when "restart" then cp.restart()
  when "stop"    then cp.stop()
  else DBlog::sto("not found #{act}")
  end
  redirect "/",301
  #slim :control
end

post '/control/*' do |act|
  cp = Control.new()
  case act
  when "fcopy"   then cp.fcopy( @params )
  end
  redirect "/",301
end

get '/control' do
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

get '/rsv_list_old/*' do |page|
  @page = page
  slim :rsv_list_old
end
get '/rsv_list_old' do
  slim :rsv_list_old
end
post '/rsv_list_old' do
  slim :rsv_list_old
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
#   log
#
get '/log_view/*/*' do |level,page|
  @level = level
  @page = page
  slim :log_view
end
get '/log_view/*' do |level|
  @level = level
  @page = 1
  slim :log_view
end
get '/log_view' do
  @level = nil
  @page = 1
  slim :log_view
end

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
#  sinatora reset
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

