#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  予約確認
#


class ReservationConfirm

  def initialize( )
  end

  #
  #  form のパラメータ設定
  #
  def setPara(  )
    d = {}
    d[:dirs]     = Commlib::datalist_dir()
    d[:jitanchk] = true
    d
  end
  
  
end

