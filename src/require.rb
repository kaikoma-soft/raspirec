#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'pp'
require 'sqlite3'
require 'fileutils'
require 'json'
require 'etc'


#
#  config
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

if Object.const_defined?(:EpgBanTime) != true
  Object.const_set("EpgBanTime", nil )
end


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

# media player モニタ機能が有効か
if Object.const_defined?(:MPMonitor) != true
  Object.const_set("MPMonitor",false )
end



require 'db/DB.rb'
require 'db/base.rb'
require 'db/Category.rb'
require 'db/Channel.rb'
require 'db/EpgTable.rb'
require 'db/Filter.rb'
require 'db/FilterResult.rb'
require 'db/Programs.rb'
require 'db/Reserve.rb'
require 'db/Keyval.rb'
require 'db/Log.rb'
require 'db/UpdateChk.rb'
require 'db/Phchid.rb'
require 'db/PTOption.rb'

require 'model/FilterM.rb'
require 'model/Reservation.rb'
require 'model/Const.rb'
require 'model/Tuner.rb'
require 'model/Timer.rb'
require 'model/Recpt1.rb'
require 'model/Confd.rb'
require 'model/GetEPG.rb'
require 'model/EpgLock.rb'
require 'model/Control.rb'
require 'model/FileCopy.rb'
require 'model/DiskKeep.rb'
require 'model/LogRote.rb'
require 'model/ChannelM.rb'
require 'model/Monitor.rb'
require 'model/EpgPatch.rb'
require 'model/MpvMonM.rb'


require 'lib/httpd_sub.rb'
require 'lib/commlib.rb'
require 'lib/misc.rb'

