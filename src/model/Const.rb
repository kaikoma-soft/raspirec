#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  定数定義
#

module Const

  ProgName = "raspirec"
  ProgVer  = "Ver 1.3.8"
  GitTag   = "Ver1.3.8"

  GR   = "GR"
  GRJ  = "地デジ"
  BS   = "BS"
  CS   = "CS"
  BSCS = "BSCS"
  GBC  = "GRBSCS"
  Wday = { 0 => "(日)",
           1 => "(月)",
           2 => "(火)",
           3 => "(水)",
           4 => "(木)",
           5 => "(金)",
           6 => "(土)", }

  FAtype      = "fa_type"
  LastEpgTime = "lastepgtime"
  GB          = 1024 * 1024 * 1024
  MB          = 1024 * 1024
  PlayListFname = "playlist.m3u8" # playList ファイル名

end

module StrConst
  Jitan  = "チューナーが競合した場合に録画時間の短縮を許可する。"
  NotUse = "この予約を無効とする。"
  Dedupe = "過去に録画したタイトルと一致した場合は無効にする。"
  FreeOnly = "無料放送のみ"
end


#
#  予約関係
#
module RsvConst

  Normal     = 0                   # 予約中 正常
  Conflict   = 1                   # 予約中 競合
  NormalEnd  = 2                   # 正常終了
  AbNormalEnd= 3                   # 異常終了
  RecNow     = 4                   # 録画中
  RecStop    = 5                   # 番組消失
  RecStop2   = 6                   # 手動操作による録画中止
  NotUseA    = 7                   # 予約無効(自動予約)
  NotUse     = 9                   # 予約無効(手動)
  WaitStat   = [0,1,7,9]           # 予約中の status
  EndStat    = [2,3,5]             # 終了した status
  RecStat    = [4]                 # 録画中の status
  ActStat    = [0,1,4]             # 有効な status
  AllStat    = [0,1,2,3,4,5,6,7,9] # All status

  Manual     = 0                   # 手動予約
  Auto       = 1                   # 自動予約
  #NotUse     = 1                   # 不使用
  #Use        = 0                   # 使用
  JitanOn    = 0                   # 時短許可
  JitanOff   = 1                   # 時短不許可
  JitanEOn   = 0                   # 録画時時短を実行する。
  JitanEOff  = 1                   #   〃            しない
  FO         = 1                   # 無料放送のみ制限する
  Off        = 0                   # off
  Dedupe     = 1                   # 重複予約を無効化
  Ftp_Complete = 1                 # 転送完了
  Ftp_AbNormal = 2                 # 異常終了
  HashSetFlag  = 999              # title の hash を設定したかのフラグ
end

#
#  フィルター関係
#
module FilConst

  Filter   = 0                   # フィルター
  AutoRsv  = 1                   # 自動予約
  RegexOn  = 1                   # 正規表現
  RegexOff = 0                   # 単純文字列検索
  TypeMan  = 0                   # 手動予約
  TypeAuto = 1                   # 自動予約
  JitanOn  = 0                   # 時短許可
  JitanOff = 1                   # 時短不許可
  BandGR   = 1                   # GR
  BandBS   = 2                   # BS
  BandCS   = 4                   # CS
  BandALL  = 7                   # GR + BS + CS
  TargetT  = 0                   # 検索対象 = タイトル
  TargetTS = 1                   # 検索対象 = タイトル＋概要
  SeachMax = 512                 # 検索最大値

end


#
#  ステータス関係
#
module StatConst
  KeyName  = "Status"
  None     = 0
  FileCopy = 1
  EPGget   = 2
  RecNow   = 4
  PacketChk = 5
end

#
#  自動予約一覧の sort type
#
module ARSort
  Title  = 0
  Reg    = 1
  Cate   = 2
  Num    = 3
  Reverse= 4
  Off    = 0                    # off
  On     = 1                    # on
  KeyNameT = "ARSortType"
  KeyNameR = "ARSortReverse"
end

#
#  フィルター一覧の sort type
#
module FilSort
  KeyNameT = "FilSortType"
  KeyNameR = "FilSortReverse"
end
