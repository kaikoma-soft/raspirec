#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  予約一覧
#
require 'sys/filesystem'

class Top

  def initialize( )
    $status = {} if $status == nil
  end

  def sec2str( sec )
    if sec > 59
      s = sec % 60
      m = sec.to_i / 60
      if m > 59
        h = m.to_i / 60
        m = m % 60
        if m != 0
          return sprintf("%d時間 %d分",h,m)
        else
          return sprintf("%d時間",h )
        end
      else
        return sprintf("%d分",m)
      end
    else
      return sprintf("%d秒",sec)
    end
  end
  
  def setup()
    r = {}

    #  Disk情報
    stat = Sys::Filesystem.stat( DataDir )
    diskTotal = (stat.blocks * stat.block_size).to_f 
    diskFree  = (stat.blocks_available * stat.block_size).to_f
    used = diskTotal - diskFree
    r[:diskTotal] = sprintf("%.1f GB", diskTotal / Const::GB )
    r[:diskFree]  = sprintf("%.1f GB", diskFree / Const::GB )
    r[:diskUsed]  = sprintf("%.1f GB", used / Const::GB )
    wari = 100.0 * used / diskTotal
    r[:diskWari]  = sprintf("%.1f %%", wari )

    # 予約情報
    now = Time.now.to_i
    reserve = DBreserve.new
    reserveNum = 0              # 予約数
    nowRecTitle = []            # 録画中のタイトル
    nextRecTime = nil           # 次の予約時間
    nextRecTitle = ""           # 次番組のタイトル
    conflictNum = 0             # 競合中の数
    epg = 0                     # EPG取得中か
    remainingTime = 0           # 録画残り時間
    stat2 = 0
    DBaccess.new().open do |db|
      row = reserve.select( db, tend: now, order: "order by start" )
      reserveNum = row.size
      row.each do |r|

        case r[:stat]
        when RsvConst::Normal then
          start2 = r[:start] - Start_margin
          if nextRecTime == nil or start2 < nextRecTime
            nextRecTime = start2
            nextRecTitle = r[:title]
          end
        when RsvConst::RecNow then
          nowRecTitle << r[:title]
          remainingTime = r[:end] if remainingTime < r[:end] 
        when RsvConst::Conflict then
          conflictNum += 1
        end
      end
      stat2 = DBkeyval.new.select(db,StatConst::KeyName )
    end

    r[:stat2] = ""
    if nowRecTitle.size > 0
      r[:stat] = sprintf("録画中 ( 残り %s )",
                         sec2str( remainingTime - Time.now.to_i ))
      r[:stat2] = nowRecTitle.join("<br>")
    else
      if test( ?f, EPGLockFN )
        r[:stat] = stat2 == StatConst::FileCopy ? "ファイル転送中" : "EPG取得中"
      elsif reserveNum == 0
        r[:stat] = "予約待ち"
      elsif nextRecTime > 0
        t = sec2str( nextRecTime - now )
        r[:stat] = sprintf("待機中 ( 開始まで %s )",t )
        r[:stat2] = nextRecTitle 
      else
        r[:stat] = "-"
      end
    end
    r[:ConflictNum] = conflictNum
    r[:reserveNum] = reserveNum

    r
  end

end

