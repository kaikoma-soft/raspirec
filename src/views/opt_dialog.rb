#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  番組表オプション
#
class Dialog_opt

  attr_reader  :sp, :hp, :tt, :hn, :chflag

  def initialize( session )

    @chflag =  session["from"] =~ /ch_tbl/ ? true : false
      
    pto = PTOption.new
    @sp = pto.sp
    @hp = pto.hp
    @hn = pto.hn
    @tt = pto.tt
  end

end

