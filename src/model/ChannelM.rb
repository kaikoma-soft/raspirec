#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  
#


class ChannelM

  def initialize( )

  end

  #
  #  skip の設定
  #
  def set( chid, skip )

    DBaccess.new().open do |db|
      db.transaction do
        channel = DBchannel.new
        val = skip == "on" ? 1 : 0
        channel.updateSkip( db, val, chid )
      end
    end
  end
  

end

