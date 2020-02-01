#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  番組表オプション
#
class Dialog_opt

  attr_reader  :sp, :hp, :tt, :hn

  def initialize(  )
    pto = PTOption.new
    @sp = pto.sp
    @hp = pto.hp
    @hn = pto.hn
    @tt = pto.tt
  end

end

