#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  
#
class Pack_chk_view

  attr_reader  :sp, :hp, :tt, :hn, :chflag

  def initialize( rid )
    @rid = rid

  end

  def print

    logfname = nil
    DBaccess.new().open do |db|
      reserve = DBreserve.new()
      r = reserve.select( db, id: @rid )
      l = r.first
      path = TSDir + "/"
      if l[:subdir] != nil and l[:subdir] != ""
        subdir2 = Commlib::normStr( l[:subdir] )
        path += subdir2.sub(/^\//,'').sub(/\/$/,'').strip + "/"
      end
      path += l[:fname]
      logfname = path + ".chk"
    end
      
    r = []
    r << "<pre>"
    if logfname != nil
      if test(?f, logfname )
        File.open( logfname, "r" ) do |fpr|
          fpr.each_line do |line|
            r << line.chomp
          end
        end
      else
        r << "file not found\n#{logfname}"
      end
    end
    r << "</pre>"
    r.join("\n")
  end
  
end

