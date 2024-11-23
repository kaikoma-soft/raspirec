#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  EPG 取得
#
require 'timeout'
require 'thread'

class ReadjsonData
  attr_reader :fname, :phch, :count, :busy, :base
  def initialize( fname, phch, count )
    @fname = fname 
    @phch  = phch 
    @count = count
    @busy  = false
    @base = File.basename( fname )
  end

  def to_a()
    return [ @fname, @phch, @count, @base ]
  end
  
  def setBusy( val )
    @busy = val
  end
end

class GetEPG

  @@queue = nil
  @@queue2 = nil
  @@queue2_busy = false
  
  def initialize(  )
    @shortTime = false          # EPG取得時間短縮モード
    @timeUpdate = true          # EPG取得時間の更新をする

    #
    #  readjsonProc() へのキュー 初期化
    #
    if @@queue == nil           
      @@queue = Queue.new
      th1 = Thread.start do
        while data = @@queue.pop
          ( outfname, phch, count, base  ) = data.to_a
          readJsonProc( outfname, phch, count  )
          data.setBusy( false )
        end
      end
    end

    #
    #  readjsonProc() へのキュー 初期化 10秒遅延 Update 付き
    #
    if @@queue2 == nil           
      @@queue2 = Queue.new
      waitTime = 10
      th1 = Thread.start do
        while data = @@queue2.pop
          @@queue2_busy = true
          ( outfname, phch, count, base ) = data.to_a
          readJsonProc( outfname, phch, count  )
          sleep(1)
          if @@queue2.size == 0
            n = 0
            while n < waitTime
              if @@queue2.size > 0
                DBlog::stoD( " break #{@@queue2.size}")
                break
              end
              sleep(1)
              n += 1
            end
            if n == waitTime
              DBlog::stoD( "with_update FilterM.new.update" )
              FilterM.new.update() # 再スケージュール
              @@queue2_busy = false
           end
          end
        end
      end
    end
    
  end

  def addQueue( data )
    data.setBusy( true )
    @@queue.push( data )
    while data.busy == true
      sleep(1)
    end
  end

  def addQueue_with_update( data )
    @@queue2_busy = true
    @@queue2.push( data )
    while @@queue2_busy == true
      sleep(1)
    end
  end

  def queueSize( data )
    return @@queue.size
  end
  
  #
  #  json ファイルの読み込み
  #
  def readJson( fname, ch, fpw )
    #DBlog::stoD("readJson(#{ch}) start")
    @ts = Time.now
    unless test(?f, fname )
      fpw.close if fpw != nil
      return false
    end
    
    count = { :upd => 0, :ins => 0, :del => 0, :same => 0 }
    data = nil
    File.open( fname, "r" ) do |fp|
      str = fp.read
      data = JSON.parse(str)
    end
    if data == nil or data.size == 0
      errorProc( ch )
      return false
    end

    channel  = DBchannel.new
    programs = DBprograms.new
    category = DBcategory.new
    phchid   = DBphchid.new
    dataI = []              # data insert
    dataU = {}              # data update
    dataC = {}              # ch update time

    DBaccess.new().open(  ) do |db|
      data.each do |d|
        ch2 = channel.select( db, chid: d["id"] )
        data2 = channel.dataConv( d, ch, nil )
        if ch2.size == 0
          channel.insert( db, data2 )
          DBlog::debug(db,"channel情報追加 #{d["name"]}" )
          ch2 = channel.select( db, chid: d["id"] )
        else
          # データに変更が無いか
          diffkey = channel.dataDiff( ch2[0], data2 )
          diffkey.each do |key|
            old = ch2[0][key]
            new = data2[key]
            DBlog::warn(db,"channel情報変更 #{data2[:name]} #{key.to_s} #{old} -> #{new}" )
            channel.update( db, d["id"], key, new )
          end
        end

        # EPG 更新日付
        if @timeUpdate == true
          now = Time.now.to_i
          dataC[ d["id"] ] = ch
        end

        chid = ch2[0][:chid]
        r = programs.select( db, chid: chid )
        cache = {}
        r.each do |r2|
          cache[ r2[ :evid ]] ||= []
          cache[ r2[ :evid ]] << r2
        end
        if $debug == true
          cache.each_pair do |k,v|
            if v.size > 1
              str = sprintf( "Warn: evid dup (%s, %s)", chid.to_s, k.to_s )
              DBlog::sto( str )
            end
          end
        end

        d["programs"].each do |pro|
          cateId = category.conv2id(db, pro["category"] )
          pro2 = programs.dataConv( db, pro, ch2[0][:chid],cateId )
          #r = programs.select( db, chid: pro2[:chid], evid: pro2[:evid] )
          r = cache[ pro2[:evid] ]
          if r == nil or r.size == 0
            next if pro2[:title] == nil or pro2[:title] == ""
            dataI << pro2
            count[:ins] += 1
          else
            r.each do |r2|
              # 拡張情報は抜ける場合があるので補正
              if r2[:extdetail] != "--- []\n"
                pro2[:extdetail] == "--- []\n"
                pro2[:extdetail] = r2[:extdetail]
              end
              if programs.diff( r2, pro2 ) == true
                dataU[ r2[:id] ] = pro2 
                count[:upd] += 1
              else
                count[:same] += 1
              end
            end
          end
        end
      end
    end

    #
    #  トランザクション時間を最小にするため分離
    #
    ts2 = Time.now
    DBaccess.new().open( tran: true ) do |db|
      now = Time.now.to_i
      dataC.each_pair do |id,ch|
        channel.update( db, id, :updatetime, now )
        phchid.add( db, ch, id, now )
      end
      if dataI.size > 0
        programs.bulkinsert2( db, dataI )
      end
      dataU.each_pair do |id, v|
        programs.update( db, id, v )
      end
    end

    if fpw != nil
      fpw.puts("upd=#{count[:upd]}")
      fpw.puts("ins=#{count[:ins]}") 
      fpw.puts("same=#{count[:same]}")
      fpw.close
    end

    str = sprintf("%-9s : ins=>%4d, upd=>%4d, same=>%4d",
                  "Ch=#{ch}",count[:ins],count[:upd],count[:same] )
    lap = ( Time.now - @ts ).to_f
    lap2 = ( Time.now - ts2 ).to_f
    str += sprintf( " : %.2f Sec (Tx %.2f Sec)",lap, lap2 )
    DBlog::sto( str )
  end

  #
  #   失敗時の処理
  #
  def errorProc( ch )
    DBaccess.new().open( tran: true ) do |db|
      phchid   = DBphchid.new
      time = Time.now.to_i - ( EPGperiod * 3600 ) + 3600
      phchid.touch( db, time, phch: ch   )
      DBlog::debug(db,"Error: ch=#{ch} の EPG 取得に失敗しました" )
    end
  end

  #
  #  EPG 取得開始
  #
  def start( timeLimit )
    start = Time.now

    return false if Time.now.to_i > ( timeLimit - 90 )

    if EpgBanTime != nil and EpgBanTime.class == Array
      EpgBanTime.each do |h|
        if h == start.hour
          #DBlog::stoD( "EPG 禁止時間帯の為、EPG 取得を中止します。")
          return false
        end
      end
    end
    DBlog::stoD( "GetEPG::start(#{Time.at(timeLimit).to_s})") 

    chs = EpgNearCh.new.check() # 直近の EPG更新
    if chs.size > 0
      @shortTime = true
      @timeUpdate = false
      DBlog::stoD( "@shortTime = true")
    else
      chs = getUpdCh()          # 定例の EPG更新
    end
    
    return false if chs.size == 0 
    
    channel = DBchannel.new
    programs = DBprograms.new
    phchid   = DBphchid.new
    DBaccess.new().open( tran: true ) do |db|
      DBlog::debug( db,"EPG取得開始" )
      DBkeyval.new.upsert( db, StatConst::KeyName, StatConst::EPGget )

      if channel.select( db ).size == 0
        @shortTime = true
        DBlog::sto( "初回時のみ EPG 取得時間短縮" )
      end
    end

    count = { :upd => 0, :ins => 0, :del => 0, :same => 0 }
    ta = $tunerArray
    ta.allClear()
    recpt1 = Recpt1.new
    recpt1.clearEpgPid()
    pids = []

    while chs.size > 0

      tcount = ta.usedCount()
      if ( Total_tuner_limit == false or Total_tuner_limit > tcount ) and
        ( EPG_tuner_limit == false or EPG_tuner_limit > tcount )

        # 空いているチューナーを探す 
        tune = phch = band = nil
        chs.each_with_index do |tmp,n|
          phch = tmp
          band = Commlib::chid2band( phch )
          if ( tune = ta.unused?(band)) != nil
            chs.delete_at(n)
            break
          end
        end
        if tune != nil

          # 中断の判断
          expect  = getRecTime( phch ) + Time.now.to_i
          if expect > ( timeLimit - 90 )
            DBlog::stoD("time limit break: #{Time.at(expect).to_s}" )
            break
          end
          if $recCount != nil and $recCount > 0
            DBlog::stoD("rec now GetEPG break" )
            return false
          end

          outfname = JsonDir + "/#{phch}.json"

          pids << Thread.new(phch, band, tune, outfname) do |phch, band,tune,outfname|
            tune.used = true
            execEpgRec( recpt1, phch, band, outfname )
            #DBlog::stoD("execEpgRec() end #{phch}" )
            tune.used = false
            rjd = ReadjsonData.new( outfname, phch, count )
            addQueue( rjd )
          end
        end
      else
        #DBlog::stoD("tuner_limit over #{tcount}" )
      end
      sleep( 3 )
    end
    pids.each {|t| t.join}
    recpt1.clearEpgPid()

    
    #
    # ガーベージコレクション
    #
    if Time.now.to_i < ( timeLimit - 90 ) # 余裕がある時
      DBlog::stoD("GC start" )
      DBaccess.new().open do |db|
        chs = channel.select( db )
      end
      while chs.size > 0
        begin
          DBaccess.new().open( tran: true ) do |db|
            st = Time.now
            while chs.size > 0
              row = chs.shift
              count[:del] += programs.gc(db, row[:chid] )
              break if ( sa = Time.now - st ) > 0.5
            end
          end
          sleep(1)
        rescue => e
          DBlog::stoD("Error: GC transaction exception" )
        end
      end
    end

    str = sprintf("ins=>%4d, upd=>%4d, same=>%4d, del=>%4d",
                  count[:ins],count[:upd],count[:same],count[:del] )

    DBaccess.new().open( tran: true ) do |db|
      phchid_gc(db)
      DBlog::debug(db,"EPG取得終了 #{str}" )
      DBkeyval.new.upsert( db, StatConst::KeyName, StatConst::None )
    end

    # BS slot の補正値の算出
    EpgAutoPatch.new( true )
    
    return true if count[:ins] > 0 or count[:upd] > 0
    return false
  end

  def phchid_gc(db)
    phchid   = DBphchid.new
    phlist = {}
    delList = {}
    updtime = {}               # chid 毎の更新時間を保存
    
    ( GR_EPG_channel + BS_EPG_channel + CS_EPG_channel ).each do |v|
      phlist[ v ] = true
    end

    row = phchid.select( db )
    row.each do |tmp|
      chid = tmp[:chid]
      if updtime[chid] == nil or updtime[chid] < tmp[:updatetime]
        updtime[chid] = tmp[:updatetime]
      end
      if phlist[ tmp[:phch] ] == nil
        delList[ tmp[:phch] ] = true
      end
    end

    delList.keys.each do |phch|
      phchid.delete( db, phch )
    end
    DBlog::stoD( "phchid_gc( #{delList.keys.join(" ")})" )
    
    row = phchid.select( db )
    row.each do |tmp|
      chid = tmp[:chid]
      if tmp[:updatetime] < updtime[chid]
        #pp "> #{chid} #{updtime[chid]}"
        phchid.touch( db, updtime[chid], chid: chid )
      end
    end

  end

  #
  #   受信の実行
  #
  def execEpgRec( recpt1, ch, band, outfname )

    thc = Thread.current        # スレッドセーフのため
    thc[:outfname_tmp] = outfname + ".tmp"
    begin
      File.unlink( outfname ) if test(?f, outfname )
      time = getRecTime( ch )
      #DBlog::stoD("execEpgRec() #{ch} #{time}" )
      recpt1.getEpgJson( ch, time, thc[:outfname_tmp] )
      if test( ?f, thc[:outfname_tmp] ) and
        File.size( thc[:outfname_tmp] ) > 100
        File.rename(thc[:outfname_tmp], outfname )
      else              # 失敗
        errorProc( ch )
        return
      end
    rescue
      errorProc( ch )
      return
    end
  end

  #
  #   Json ファイルの読み込み( json の読み込みで、メモリが肥大する対策 )
  #
  def readJsonProc( fname, ch, count )
    reader, writer = IO.pipe
    pid = fork do  
      reader.close
      begin
        Timeout.timeout( 30 ) do
          readJson( fname, ch, writer )
        end
      rescue Timeout::Error
        pid2 = Process.pid
        str = "Error: readJson() time out kill #{pid2} #{ch}"
        DBlog::sto( str )
        Process.kill(:KILL, pid2 );
        DBlog::debug(nil, str )
      end
    end
    writer.close
    while message = reader.gets()
      if message =~ /(ins|upd|same)=(\d+)/
        type = $1
        n = $2.to_i
        count[type.to_sym] += n
      end
    end
    Process.waitpid( pid )
  end

  #
  #  EPG取得時間
  #
  def getRecTime(ch)
    ch2 = ch.to_i
    time = case ch
           when /^\d+$/ then
             ch2 < 100 ? GR_EpgRsvTime : BS_EpgRsvTime
           when /^BS/  then BS_EpgRsvTime
           when /^CS/  then CS_EpgRsvTime
           else
             raise "予期しないチャンネルの書式です。 #{ch}"
           end

    if @shortTime == true
      time = 60 if time > 60
      #DBlog::stoD( "getRecTime() time = #{time}" )
    end
    
    return time
  end

  #
  #  更新対象のch を抽出
  #
  def getUpdCh()
    chs = []                    # EPG対象チャンネル
    chlist = {}                 # DBにあるチャンネル list
    phchid   = DBphchid.new
    th = Time.now.to_i - ( EPGperiod * 3600 )
    DBaccess.new().open do |db|
      row = phchid.select(db)
      row.each do |r|
        phch = r[:phch]
        chlist[ phch ] = true
        if r[:updatetime] < th
          band = Commlib::chid2band( r[:chid] )
          chs << phch
        end
      end
    end
    chs.uniq!

    # DB に無い ch を追加
    if GR_tuner_num > 0
      GR_EPG_channel.each {|v| chs << v if chlist[v] == nil }
    end
    if BSCS_tuner_num > 0
      BS_EPG_channel.each {|v| chs << v if chlist[v] == nil }
      CS_EPG_channel.each {|v| chs << v if chlist[v] == nil }
    end
    if GBC_tuner_num > 0
      GR_EPG_channel.each {|v| chs << v if chlist[v] == nil }
      BS_EPG_channel.each {|v| chs << v if chlist[v] == nil }
      CS_EPG_channel.each {|v| chs << v if chlist[v] == nil }
    end

    return chs
  end

  #
  #  録画途中の EPG更新の入り口
  #
  def tailEpgStart( fname, ch )
    DBlog::stoD( "tailEpgStart() start" )
    count = { :upd => 0, :ins => 0, :del => 0, :same => 0 }
    if test( ?f, fname )
      rjd = ReadjsonData.new( fname, ch, count )
      addQueue_with_update( rjd )
    else
      DBlog::sto( "Error: json file not found #{fname}")
    end
    DBlog::stoD( "tailEpgStart() end" )

    if count[:ins] > 0 or count[:upd] > 0
      return true
    end
    return false
  end
  
end


if File.basename($0) == "GetEPG.rb"
  base = File.dirname( $0 )
  [ ".", "..","src", base ].each do |dir|
    if test( ?f, dir + "/require.rb")
      $: << dir
      $baseDir = dir
    end
  end
  require 'require.rb'

  $rec_pid = []
  $debug = true

  #
  #  録画開始に伴う EPG の中止
  #
  def sigUsr2()
    DBlog::stoD( "sigUsr2()" )
    Recpt1.new.killEpgPid()
  end

  Signal.trap( :USR2 ) do
    DBlog::stoD("Signal.trap :USR2")
    $recCount = 1
    sigUsr2()
  end

  $tunerArray = TunerArray.new
  ge = GetEPG.new
  type = 1
  
  if type == 0
    phchid  = DBphchid.new
    DBaccess.new().open( tran: true ) do |db|
      #phchid.touch( db, (Time.now - 3600 * 24 ).to_i, chid: "BS_141" )
    end
  
    ge.start( Time.now.to_i + 600 )
  elsif type == 1
    fname = ENV["HOME"] + "/data/rrtest/json/CS4.json"
    ch = "CS4"
    fpw = STDOUT
    ge.readJson( fname, ch, fpw )
  end
  
  exit
  
end

