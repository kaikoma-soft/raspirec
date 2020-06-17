#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  モニター
#
require_relative 'monitor.rb'

class MpvMon <  Monitor

  attr_reader :statS, :devfn, :base_url

  def initialize( devfn, cmd )

    super()
    @devfn = devfn == nil ? $mpvMon.data.keys.sort.first : devfn
    @cmd = cmd == nil ? "disp" : cmd       
    $mpvMon.chkDeviceStat()

    if $mpvMon.devs2.include?(@devfn)
      @statS = $mpvMon.data[ @devfn ].getStatStr()
      @base_url = "/mpv_mon/#{@devfn}"
    else
      @base_url = "/mpv_mon"
      @devfn = nil
    end

  end


  #
  #  device 選択
  #
  def deviceSelect()
    hina = %q( <label>
      <input name="devfn" type="radio" value="%s" %s>
         <span class="radio %s"> %s </span>
      </input>
    </label>)

    list = $mpvMon.devs2.sort
    a = []
    list.each do |dev|
      sel = $mpvMon.data[dev].devfn == @devfn ? "checked" : ""
      tmp = $mpvMon.data[dev].devfn
      stat = $mpvMon.data[dev].stat == :OK ? "" : "busy"
      a << sprintf( hina, tmp, sel, stat, tmp )
    end
    a.join("\n")
  end

  #
  #  選局中のチャンネル
  #
  def selCh()
    return "-" if @devfn == nil or $mpvMon.data[@devfn].chName == nil
    return $mpvMon.data[@devfn].chName
  end
  
  #
  #  選局中の番組名
  #
  def prog_name()
    return "-" if @devfn == nil or $mpvMon.data[@devfn].prog_name == nil
    return $mpvMon.data[@devfn].prog_name
  end
  
  #
  #  選局中の番組概要
  #
  def prog_detail()
    return "-" if @devfn == nil or $mpvMon.data[@devfn].prog_detail == nil
    return $mpvMon.data[@devfn].prog_detail
  end
  
  #
  #  有効なバンドを返す。
  #
  def bands()
    r = $mpvMon.data[@devfn].band
    return r.keys.sort
  end

  def activeBand?( band )
    return $mpvMon.data[ @devfn ].selBand == band ? "active" : ""
  end
  
  def stop_a()
    "<a href=\"/mpv_mon/#{@devfn}/stop\">  停止 </a>"
  end


  def dis_stop(  )
    return $mpvMon.data[ @devfn ].rec_pid == nil ? "disabled" : ""
  end
end
