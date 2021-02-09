#!/usr/bin/ruby
# -*- coding: utf-8 -*-


class DBaccess

  #
  #  SQLite の初期化
  #
  def createDB()

    sql = <<EOS
--
-- チャンネル情報
--
create table channel (
    id                  integer  primary key,
    band                text,     -- GR,BS,CS
    band_sort           text,     -- sort 順
    chid                text,     -- chanel_id
    tsid                integer,  -- transport_stream_id
    onid                integer,  -- original_network_id
    svid                integer,  -- service_id
    name                text,
    stinfo_tp           text,     -- GRは、物理、衛星は satelliteinfo_tp
    stinfo_slot         text,     -- 衛星のみ  satelliteinfo_slot
    updatetime          integer,  -- prg更新日時。-1 の場合はデータ無効
    skip                integer   -- 1: skip(対象外にする。)
);
create index ch1 on channel (chid) ;
create index ch2 on channel (svid) ;
create index ch3 on channel (updatetime);
create index ch4 on channel (band);
create index ch5 on channel (id);
create index ch6 on channel (skip);

--
-- 物理チャンネル 対 chid
--
create table phchid (
    id                  integer  primary key,
    phch                text,     -- 物理チャンネル
    chid                text,     -- chanel_id
    updatetime          integer   -- EPG更新日時(対phch)
);
create index pc1 on phchid (chid) ;
create index pc2 on phchid (phch) ;
create index pc3 on phchid (updatetime) ;


create table categoryL (          -- large
    id                  integer  primary key,
    name                text
);
create index cm1 on categoryL (id) ;
create index cm2 on categoryL (name) ;

create table categoryM (          -- middle
    id                  integer  primary key,
    pid                 integer,  -- categoryL.id
    name                text
);
create index cs1 on categoryM (id) ;
create index cs2 on categoryM (pid) ;
create index cs3 on categoryM (name) ;

--
--  プログラム情報
--
create table programs (
    id                  integer  primary key,
    chid                integer,  -- chanel_id
    evid                integer,  -- event_id
    title               text,
    detail              text,     -- 内容
    extdetail           text,     -- 拡張情報
    start               integer,
    end                 integer,
    duration            integer,
    categoryT1          text,     -- category
    categoryT2          text,     -- category
    categoryT3          text,     -- category
    category            blob,     -- 数値化し多重化した category
    attachinfo          text,     -- 付加情報
    video               text,
    audio               text,
    freeCA              bool,
    wday                integer,  -- 曜日  (0..6); 0 を日曜日とする
    updtime             integer   -- 更新日時
);  -- 20

create index pm1 on programs (id) ;
create index pm2 on programs (evid) ;
create index pm3 on programs (start) ;
create index pm4 on programs (chid) ;
create index pm5 on programs (chid,evid) ;
create index pm6 on programs (categoryT1) ;
create index pm7 on programs (categoryT2) ;
create index pm8 on programs (categoryT3) ;
create index pm9 on programs (freeCA) ;

--
--  予約テーブル
--
create table reserve (
    id                  integer  primary key,
    chid                integer,  -- channel.id
    svid                integer,  -- service_id
    evid                integer,  -- event_id
    title               text,
    start               integer,
    end                 integer,
    duration            integer,
    type                integer,   -- 0:手動 1:自動
    keyid               integer,   -- 自動の場合の keyword.id
    jitan               integer,   -- 0: 許可 1: 不許可
    jitanExe            integer,   -- 0: 実行 1: 実行しない
    stat                integer,   -- ステータス 0:予約中 正常
                                   --            1:予約中 競合あり
                                   --            2:終了   正常
                                   --            3:終了   異常
                                   --            4:録画中
                                   --            5:録画中止
    comment             text,      -- コメント
    subdir              text,      -- 格納 subDir
    fname               text,      -- TS ファイル名
    ftp_stat            integer,   -- 転送ステータス 0:未 1:完了
    tunerNum            integer,   -- チューナー番号
    recpt1pid           integer,   -- recpt1 プロセスID
    category            integer,   -- programs は消えるので保存用
    dedupe              bool,      -- 重複排除  0:しない  1:する (自動のみ)
    dropNum             integer    -- 予約
);  -- 
create index res1 on reserve (id) ;
create index res3 on reserve (type) ;
create index res4 on reserve (stat) ;
create index res5 on reserve (svid,evid) ;
create index res6 on reserve (chid,evid) ;
create index res7 on reserve (dedupe) ;
create index res8 on reserve (ftp_stat) ;


--
--  条件検索 (番組表＋自動予約)
--
create table filter (
    id                integer  primary key,
    type              integer,     -- 0: 番組表, 1:自動予約
    title             text,        -- 題名
    key               text,        -- 検索文字列
    exclude           text,        -- 除外文字列
    regex             integer,     -- 1:正規表現  0:単純検索
    band              integer,     -- 3bit 1bit:GR 2bit:BS 3bit:CS
    target            integer,     -- 2bit 1bit:タイトル 2bit:概要 
    chanel            text,        -- "0":全部 文字列で格納。複数の場合は"," で区切って
    category          text,        -- 同上
    wday              integer,     -- 曜日 127 で全部, 
                                   --      1:日曜日  2 ** 0
                                   --      2:月曜日  2 ** 1
                                   --      4:火曜日  2 ** 3
                                   --      8:水曜日  2 ** 4
                                   --     16:木曜日  2 ** 5
                                   --     32:金曜日  2 ** 6
                                   --     64:土曜日  2 ** 7
    result            integer,     -- 検索結果の件数
    jitan             integer,     -- 1-2bit: 時短     0: 許可 1: 不許可
                                   -- 3-4bit: 放送時間 0:全て 1: 以上 2: 未満
                                   -- 5-16bit: 時間
    subdir            text,        -- 格納 subDir
    dedupe            bool,        -- 重複排除  0:しない  1:する
    freeonly          bool         -- 無料放送のみに制限  0:しない  1:する
); --   
create index fil1 on filter (id) ;
create index fil2 on filter (type) ;


--
--  条件検索の結果
--
create table filter_result (
    id                integer  primary key,
    pid               integer,     -- 親のID ( filter.id )
    rid               integer      -- 検索した programs.id
); --   
create index filr1 on filter_result (id) ;
create index filr2 on filter_result (pid) ;

--
--  変数保存
--
create table keyval (
    key               text primary key,     -- キー
    val               integer               -- 値 
); --   
create index keyval1 on keyval (key) ;

--
--  log
--
create table log (
    id                integer  primary key,
    level             integer,               -- レベル
    time              integer,               -- 時間
    str               text                   -- 文字列
); --   
create index log1 on log (level) ;
create index log2 on log (time) ;


EOS
    
    @db.execute_batch(sql)
    initDB()
  end

  #
  #  DB の中身の初期化
  #
  def initDB()
    ( l1,l2 ) = category()
    sql1 = "insert into categoryL ( name ) values ( ? )"
    sql2 = "select last_insert_rowid();"
    sql3 = "insert into categoryM ( pid,name ) values ( ?,? )"
    l1.each_pair do |k,v|
      @db.execute( sql1, v )
      row = @db.execute( sql2 )
      pid = row[0][0]
      if l2[ k ] != nil
        l2[ k ].each_pair do |k2,v2|
          @db.execute( sql3, pid, v2  )
        end
      end
    end
  end

  #
  # テレビ番組カテゴリー一覧 ARIB STD-B10 
  #
  def category()
    cateL1 = {
      "01" => "ニュース／報道",
      "02" => "スポーツ",
      "03" => "情報／ワイドショー",
      "04" => "ドラマ",
      "05" => "音楽",
      "06" => "バラエティ",
      "07" => "映画",
      "08" => "アニメ／特撮",
      "09" => "ドキュメンタリー／教養",
      "10" => "劇場／公演",
      "11" => "趣味／教育",
      "12" => "福祉",
      "13" => "拡張",
      "15" => "その他",
    }

    cateL2 = {
      "01" => {
        "0100" => "定時・総合",
        "0101" => "天気",
        "0102" => "特集・ドキュメント",
        "0103" => "政治・国会",
        "0104" => "経済・市況",
        "0105" => "海外・国際",
        "0106" => "解説",
        "0107" => "討論・会談",
        "0108" => "報道特番",
        "0109" => "ローカル・地域",
        "0110" => "交通",
        "0115" => "その他"
      },
      "02" => {
        "0200" => "スポーツニュース",
        "0201" => "野球",
        "0202" => "サッカー",
        "0203" => "ゴルフ",
        "0204" => "その他の球技",
        "0205" => "相撲・格闘技",
        "0206" => "オリンピック・国際大会",
        "0207" => "マラソン・陸上・水泳",
        "0208" => "モータースポーツ",
        "0209" => "マリン・ウィンタースポーツ",
        "0210" => "競馬・公営競技",
        "0215" => "その他",
      },
      "03" => {
        "0300" => "芸能・ワイドショー",
        "0301" => "ファッション",
        "0302" => "暮らし・住まい",
        "0303" => "健康・医療",
        "0304" => "ショッピング・通販",
        "0305" => "グルメ・料理",
        "0306" => "イベント",
        "0307" => "番組紹介・お知らせ",
        "0315" => "その他",
      },
      "04" => {
        "0400" => "国内ドラマ",
        "0401" => "海外ドラマ",
        "0402" => "時代劇",
        "0415" => "その他",
      },
      "05" => {
        "0500" => "国内ロック・ポップス",
        "0501" => "海外ロック・ポップス",
        "0502" => "クラシック・オペラ",
        "0503" => "ジャズ・フュージョン",
        "0504" => "歌謡曲・演歌",
        "0505" => "ライブ・コンサート",
        "0506" => "ランキング・リクエスト",
        "0507" => "カラオケ・のと゛自慢",
        "0508" => "民謡・邦楽",
        "0509" => "童謡・キッズ",
        "0510" => "民族音楽・ワールドミュージック",
        "0515" => "その他",
      },
      "06" => {
        "0600" => "クイズ",
        "0601" => "ゲーム",
        "0602" => "トークバラエティ",
        "0603" => "お笑い・コメディ",
        "0604" => "音楽バラエティ",
        "0605" => "旅バラエティ",
        "0606" => "料理バラエティ",
        "0615" => "その他",
      },
      "07" => {
        "0700" => "洋画",
        "0701" => "邦画",
        "0702" => "アニメ",
        "0715" => "その他",
      },
      "08" => {
        "0800" => "国内アニメ",
        "0801" => "海外アニメ",
        "0802" => "特撮",
        "0815" => "その他",
      },
      "09" => {
        "0900" => "社会・時事",
        "0901" => "歴史・紀行",
        "0902" => "自然・動物・環境",
        "0903" => "宇宙・科学・医学",
        "0904" => "カルチャー・伝統文化",
        "0905" => "文学・文芸",
        "0906" => "スポーツ",
        "0907" => "ドキュメンタリー全般",
        "0908" => "インタビュー・討論",
        "0915" => "その他",
      },
      "10" => {
        "1000" => "現代劇・新劇",
        "1001" => "ミュージカル",
        "1002" => "ダンス・バレエ",
        "1003" => "落語・演芸",
        "1004" => "歌舞伎・古典",
        "1015" => "その他",
      },
      "11" => {
        "1100" => "旅・釣り・アウトドア",
        "1101" => "園芸・ペット・手芸",
        "1102" => "音楽・美術・工芸",
        "1103" => "囲碁・将棋",
        "1104" => "麻雀・パチンコ",
        "1105" => "車・オートバイ",
        "1106" => "コンピュータ・TVゲーム",
        "1107" => "会話・語学",
        "1108" => "幼児・小学生",
        "1109" => "中学生・高校生",
        "1110" => "大学生・受験",
        "1111" => "生涯教育・資格",
        "1112" => "教育問題",
        "1115" => "その他",
      },
      "12" => {
        "1200" => "高齢者",
        "1201" => "障害者",
        "1202" => "社会福祉",
        "1203" => "ボランティア",
        "1204" => "手話",
        "1205" => "文字(字幕)",
        "1206" => "音声解説",
        "1215" => "その他",
      },
    }

    [ cateL1,cateL2 ]
  end
end
