#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  BS の slot ずれの補正
#

class EpgAutoPatch

  @@bsChSlot = nil
  @@convTable = nil
  @@test      = false
  
  def initialize( reset = false )
    #DBlog::sto( "EpgAutoPatch(#{reset})" )
    if reset == true
      @@bsChSlot = nil 
      @@convTable = nil
    end
    if Object.const_defined?(:EpgPatchEnable) == true
      if ( EpgPatchEnable == :auto and Recpt1_cmd =~ /recpt1/ ) or EpgPatchEnable == true
        if @@bsChSlot == nil
          count = chList()
          if count < 10             # 正常なら 10局以上あるはず
            @@convTable = nil
          else
            if @@test == true
              DBlog::sto( "注意: *********  EpgAutoPatch test mode *********" )
              reset( 13, 0)
              reset( 23, 0)
              reset( 23, 1)
              reset( 19, 2)
              set( 11, 2, "放送大学" )
            end
            calc()
          end
        end
      end
    end
  end

  #
  #  ch データから BSの ch,slot を抽出
  #
  def chList()
    #DBlog::sto( "EpgAutoPatch::chList" )
    count = 0
    @@bsChSlot = {}
    th = Time.now.to_i - ( 3600 * 24 * EPGperiod )
    channel = DBchannel.new
    
    DBaccess.new().open( ) do |db|
      channel.select(db).each do |tmp|
        if tmp[:band] == "BS"
          if tmp[:updatetime] > th
            tp = $1.to_i if tmp[:stinfo_tp] =~ /BS(\d+)/
            slot = tmp[:stinfo_slot].to_i
            @@bsChSlot[ tp ] ||= {}
            if @@bsChSlot[ tp ][ slot ] == nil
              @@bsChSlot[ tp ][ slot ] = tmp[:name]
              count += 1
            end
          end
        end
      end
    end

    return count
  end

  #
  #  BS スロットの歯抜けを変換するテーブルを作成
  #
  # 参考 https://github.com/tsukumijima/ISDBScanner/blob/master/isdb_scanner/analyzer.py
  #
  def calc()
    @@convTable = nil
    @@bsChSlot.keys.sort.each do |ch|
      slots = @@bsChSlot[ch].keys.sort
      max   = slots.max
      if ( slots.size - 1) != slots.last
        lost = 0
        0.upto( max ) do |slotN|
          if @@bsChSlot[ch][slotN] == nil
            lost += 1
          else
            break
          end
        end

        if lost > 0             # 変換テーブルの作成
          slots.each do |slot|
            from = sprintf("BS%d_%d",ch, slot )
            to   = sprintf("BS%d_%d",ch, slot - lost )
            @@convTable ||= {}
            @@convTable[ from ] = to
          end
        end
      end
    end
    return @@convTable
  end
    
  
  #
  # BSXX_Y を入力して、スロットのずれを補正したものを返す
  #
  def bsSlotAdj( bsch )
    if bsch =~ /^BS(\d+)_(\d+)/
      if @@convTable != nil and @@convTable[ bsch ] != nil
        return @@convTable[ bsch ]
      end
    end
    return bsch
  end

  #
  #  debug用 に、空きスロットを作る。
  #
  def reset(x,y)
    if @@bsChSlot[x] != nil
      @@bsChSlot[x].delete(y) if @@bsChSlot[x] != nil
    else
      raise "Error: "
    end
  end
  #
  #  debug用 に、ダミーを挿入
  #
  def set(x,y, name )
    @@bsChSlot[x] ||= {}
    @@bsChSlot[x][y] = name
  end

  def p()
    pp @@bsChSlot
  end

  #
  #  デバック用の チャンネル割当表
  #
  def print()
    chs = @@bsChSlot.keys.sort
    slotMax = -1
    chs.each do |ch|
      max = @@bsChSlot[ch].keys.max
      slotMax = max if slotMax < max
    end

    printf "     CH"
    chs.each {|ch| printf("%8s",ch ) }
    puts
    0.upto( slotMax ) do |slot|
      printf("slot %d ", slot ) 
      chs.each do |ch|
        #name = @@bsChSlot[ch][slot] == nil ? "" : @@bsChSlot[ch][slot]
        name = @@bsChSlot[ch][slot] == nil ? "" : sprintf("BS%d_%d",ch,slot)
        printf("%8s",name ) 
      end
      puts
    end
  end

  #
  #  チャンネル情報で表示する表を生成
  #
  def printConvHtml()
    buf = []
    if @@convTable != nil
      @@convTable.each_pair do |k,v|
        name = ""
        if k =~ /BS(\d+)_(\d+)/
          ( ch, slot ) = [ $1.to_i, $2.to_i ]
          if @@bsChSlot[ch] != nil and @@bsChSlot[ch][slot] != nil
            name = @@bsChSlot[ch][slot]
          end
        end
        buf << "<tr> <td> #{name} </td>"
        buf << sprintf( "<td> %s </td> <td> %s </td>\n", k, v )
        buf << "</tr>"
      end
    else
      buf << "<tr> <td> 補正なし </td>"
    end
    return buf.join("\n")
  end
  
  #
  #  チャンネル情報で表示する表を生成
  #
  def printBschHtml()

    buf = []
    if @@bsChSlot != nil 
      chs = @@bsChSlot.keys.sort
      slotMax = -1
      chs.each do |ch|
        max = @@bsChSlot[ch].keys.max
        slotMax = max if slotMax < max
      end
      
      buf << "<tr> <td> </td>"
      chs.each {|ch| buf << sprintf("<th>BS%s</th>",ch ) }
      buf << "</tr>"

      0.upto( slotMax ) do |slot|
        buf << "<tr>"
        buf << sprintf("<th>slot %d</th>\n", slot ) 
        chs.each do |ch|
          name = @@bsChSlot[ch][slot]
          bsch = sprintf("BS%d_%d",ch,slot )
          cl = ""
          if @@convTable != nil and @@convTable[ bsch ] != nil
            cl = "class=\"ex_border\""
            name = "↑ " + name
          end
          buf << sprintf("<td %s> %s </td>",cl, name == nil ? "" : name ) 
        end
        buf << "</tr>"
      end
    end
    return buf.join("\n")
  end
  
end

if $0 == __FILE__

  base = File.dirname( $0 )
  [ ".", "..","src", base ].each do |dir|
    if test( ?f, dir + "/require.rb")
      $: << dir
      $baseDir = dir
    end
  end
  require 'require.rb'

  if ( Object.const_defined?(:EpgPatchEnable) == true ) 
    constRewrite( "EpgPatchEnable", :auto )
  end
  
  eap = EpgAutoPatch.new
  eap.print()

  #eap.p()
  eap.reset( 23, 0)
  eap.reset( 23, 1)
  #eap.reset( 9, 0)
  eap.reset( 1, 0)
  eap.reset( 3, 1)
  #eap.reset( 19, 1)
  eap.reset( 19, 2)
  eap.set( 11, 2, "放送大学" )
  pp eap.calc()
  
  test = %W( BS23_2 BS13_4 BS3_1 BS9_0 BS3_3 )
  test.each do |tmp|
    tmp2 = eap.bsSlotAdj( tmp )
    printf("%s -> %s\n",tmp,tmp2 )
  end

  EpgAutoPatch.new.print()

  
end
  
    
