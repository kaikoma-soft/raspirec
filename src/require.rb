#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'pp'
require 'sqlite3'
require 'fileutils'
require 'json'
require 'etc'

require 'lib/setConst.rb'   # 最初に

require 'lib/httpd_sub.rb'
require 'lib/commlib.rb'
Commlib::makeSubDir()

require 'lib/misc.rb'
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

require 'lib/rewriteConst.rb'   # DB の後に

require 'model/Const.rb'
require 'model/Tuner.rb'
require 'model/TunerArray.rb'
require 'model/TunerAssign2.rb'
require 'model/FilterM.rb'
require 'model/Reservation.rb'
require 'model/Timer.rb'
require 'model/Recpt1.rb'
require 'model/EpgLock.rb'
require 'model/Control.rb'
require 'model/FileCopy.rb'
require 'model/DiskKeep.rb'
require 'model/LogRote.rb'
require 'model/ChannelM.rb'
require 'model/Monitor.rb'
require 'model/PacketChk.rb'
require 'model/EpgNearCh.rb'
require 'model/GetEPG.rb'
require 'model/Daily.rb'
require 'model/EpgAutoPatch.rb'
