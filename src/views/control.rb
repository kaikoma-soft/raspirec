#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  コントロール パネル
#
require 'find'

class Control

  def initialize(  )
  end

  #
  #  from の初期値
  #
  def getData( )
    ret = { :tsft => false }
    keyval = DBkeyval.new
    DBaccess.new().open do |db|
      db.transaction do
        row = keyval.select( db, "tsft" )
        if row == "true"
          ret[ :tsft ] = true
        end
      end
    end

    ts = []
    Find.find( TSDir ) do |f|
      if f =~ /\.ts$/
        f.sub!( TSDir + "/", '')
        ts << sprintf("<option value=\"%s\"> %s </option>",f,f)
      end
    end
    ret[:tsfile] = ts.join("\n")
    
    return ret
  end
  
end
