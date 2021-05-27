#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  モニター
#
require_relative 'monitor.rb'

class MpvMon <  Monitor

  attr_reader :statS, :devfn, :base_url

  @@ta = nil

  def initialize( num, cmd )

    super()
    @ta = $tunerArray
    @currenTune = nil
    @devfn      = nil
    @tunNum     = nil
    
    if num == nil
      @tunNum = @ta.first.serial
    else
      @tunNum = num.to_i
    end

    @ta.each do |t1|
      if t1.serial == @tunNum
        @currenTune = t1        # 現在選択中のチューナー
        @devfn  = @currenTune.devfn
        break
      end
    end
                             
    @cmd = cmd == nil ? "disp" : cmd
    @ta.chkDeviceStat()
    if @currenTune != nil
      @statS = @currenTune.getStatStr()
      @base_url = "/mpv_mon/#{@tunNum}"
    else
      @base_url = "/mpv_mon"
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

    a = []
    @ta.each do |t1|
      if t1.devfn != nil
        dev = t1.devfn
        sel = t1.serial == @tunNum ? "checked" : ""
        name = t1.name
        stat = t1.stat == :OK ? "" : "busy"
        a << sprintf( hina, t1.serial, sel, stat, name )
      end
    end
      a.join("\n")
  end

  #
  #  選局中のチャンネル
  #
  def selCh()
    return "-" if @devfn == nil or @currenTune.chName == nil
    return @currenTune.chName
  end
  
  #
  #  選局中の番組名
  #
  def prog_name()
    return "-" if @devfn == nil or @currenTune.prog_name == nil
    return @currenTune.prog_name
  end
  
  #
  #  選局中の番組概要
  #
  def prog_detail()
    return "-" if @devfn == nil or @currenTune.prog_detail == nil
    return @currenTune.prog_detail
  end
  
  #
  #  有効なバンドを返す。
  #
  def bands()
    r = []
    if @currenTune != nil
      r << "GR" if @currenTune.band[ Const::GR ] == true
      r << "BS"  if @currenTune.band[ Const::BSCS ] == true
      r << "CS"  if @currenTune.band[ Const::BSCS ] == true
    end
    return r
  end

  def activeBand?( band )
    if @currenTune != nil
      return @currenTune.band[ band ] == true ? "active" : ""
    end
    return ""
  end
  
  def stop_a()
    "<a href=\"/mpv_mon/#{@tunNum}/stop\">  停止 </a>"
  end


  def dis_stop(  )
    if @currenTune != nil
      return @currenTune.rec_pid == nil ? "disabled" : ""
    end
    return ""
  end
end
