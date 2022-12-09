# coding: utf-8

require 'lib/deviceChk.rb'

#
#  config の設定
#
files = [ ]
files << ENV["RASPIREC_CONF_OPT"] if ENV["RASPIREC_CONF_OPT"] != nil
files << ENV["RASPIREC_CONF"] if ENV["RASPIREC_CONF"] != nil
files << ENV["HOME"] + "/.config/raspirec/config.rb"
files.each do |cfg|
  if test( ?f, cfg )
    require cfg
    ConfigPath = cfg
    break
  end
end
raise "config not found" if Object.const_defined?(:BaseDir) != true


#
#  後から追加した定数のデフォルト設定
#

if Object.const_defined?(:TitleRegex) != true
  tmp = [        # 題名の削除フィルターが未定義の場合のデフォルト
    /【N】/,
    /【SS】/,
    /【デ】/,
    /【再】/,
    /【双】/,
    /【多】/,
    /【天】/,
    /【字】/,
    /【新】/,
    /【無】/,
    /【解】/,
    /【終】/,
    /【初】/,
  ]
  Object.const_set("TitleRegex",tmp )
end

if Object.const_defined?(:SearchStringRegex) != true
  tmp = [        # 検索文字列の削除フィルターが未定義の場合のデフォルト
    /\#\d+\s?[・-]\s?\#\d+/,
    /[\#♯＃][１２３４５６７８９０\d]+/,
    /第[一二三四五六七八九十１２３４５６７８９０\d]+話/,
    /「.*」/,
  ] + TitleRegex
  Object.const_set("SearchStringRegex",tmp )
end


#
#   定数が設定されていない場合にデフォルト値を設定
#
def setDefaultConst( name, val )
  sym = name.to_sym
  if Object.const_defined?( sym ) != true
    Object.const_set(sym, val )
  end
end

setDefaultConst("MPMonitor",false )
setDefaultConst("GBC_tuner_num", 0 )
setDefaultConst("DeviceList_GBC",[])
setDefaultConst("EpgBanTime", nil )
setDefaultConst("DeviceChkFN", DBDir + "/devicechk.yaml" )
setDefaultConst("EPG_tuner_limit",false )
setDefaultConst("Browser_cmd", "/usr/bin/firefox" )
setDefaultConst("AutoRecExt", false )
setDefaultConst("ARE_sampling_time", 90 )
setDefaultConst("ARE_epgdump_opt", %w( --tail 50M ) )


#
# パケットチェック機能を有効にするか？
#
if ( Object.const_defined?(:PacketChk_enable) == true ) &&
   PacketChk_enable == true 
  if Object.const_defined?(:PacketChk_cmd) == true &&
     test( ?f, PacketChk_cmd )
    Object.const_set("PacketChkRun", true )
  else
    tmp = sprintf("PacketChk_cmd not found %s : PacketChk_enable -> false\n",PacketChk_cmd)
    DBlog::warn( nil,tmp)
    Object.const_set("PacketChkRun", false )
  end
else
  Object.const_set("PacketChkRun", false )
end

