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
files << ENV["RASPIREC_CONF"] if ENV["RASPIREC_CONF"] != nil
files << ENV["HOME"] + "/.config/raspirec/config.rb"
files.each do |cfg|
  if test( ?f, cfg )
    require cfg
    ConfigPath = cfg
    break
  end
end
raise "counfig not found" if Object.const_defined?(:BaseDir) != true


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

require 'lib/httpd_sub.rb'
require 'lib/commlib.rb'
require 'lib/misc.rb'

