#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  タイマー
#
class ReservExtOn < StandardError; end

class Timer

  def initialize( )
    @sleepT = 5
    @loopT  = 1800
  end
  
  #
  #   録画対象を抽出
  #
  def getNextProg()
    reserve = DBreserve.new
    channel = DBchannel.new
    keyval = DBkeyval.new
    now = Commlib::getNow  #Time.now.to_i
    readyTime = now + Start_margin + 10
    nextRecTime = now + 3600 * 24
    queue = []
    recC = 0 
    
    DBaccess.new().open do |db|
      row = reserve.selectSP( db, stat: RsvConst::Normal, order: "order by start" )
      row.each do |r|
        next if r[:stat] == RsvConst::NotUse or r[:stat] == RsvConst::NotUseA
        if r[:stat] == RsvConst::Normal
          start2 = r[:start] - Start_margin
          nextRecTime = start2 if start2 < nextRecTime
          if start2 < readyTime and r[:end] > now
            DBlog::sto("録画準備開始 #{r[:title]}")
            reserve.updateStat( db, r[:id], stat: RsvConst::RecNow )
            r2 = channel.select( db, chid: r[:chid] )
            r2.first.each_pair do |k,v|
              r[k] = v if r[k] == nil
            end
            queue << r
          elsif r[:end] < ( now - 60 )
            tremRec( db, r, "未開始" )
          end
        end
      end
        
      # 録画中のまま放置されたものの後処理
      row = reserve.selectSP( db, stat: RsvConst::RecNow )
      row.each do |r|
        if r[:stat] == RsvConst::RecNow
          if r[:end] < ( now - 60 )
            tremRec( db, r, "終了処理未了" )
          else
            recC += 1
          end
        end
      end
    end
    return [ queue, recC, nextRecTime ]
  end
  
  #
  #   タイマー main 開始
  #
  def start()

    #
    # ディスク容量確保
    #
    if DiskKeepPercent != false and DiskKeepPercent.to_i > 0
      Thread.new do
        begin
          DBlog::sto( "DiskKeep start" )
          lastTimeD = Time.now 
          while true
            if ( Time.now - lastTimeD ) > ( 3 * 3600 )
              DBaccess.new().open do |db|
                DiskKeep.new.start(db)
              end
              lastTimeD = Time.now
            end
            sleep( 3601 )
          end
        end
      end
    end
    
    while true
      now = Time.now.to_i

      #
      #  録画ルーチン
      #
      ( queue, $recCount, nextRecTime ) = getNextProg()

      # mpv モニタの停止 & EPG取得の停止
      if queue.size > 0
        Control.new.sendSignal( HttpdPidFile, :USR1 )
        if Recpt1.new.killEpgPid() > 0
          DBlog::sto( "録画開始の為 EPG取得を中止しました。" )
          sleep(3)
        end
      end

      queue.each do |r|
        Thread.new do
          begin
            recStart( r )       # 録画
          rescue
            puts $!
            puts $@
          end
        end
      end

      waitT = nextRecTime - now
      time_limit = nextRecTime - 30
      if waitT > 3600
        sleepTime = @loopT
        Daily.new.run()
      elsif waitT.between?( 120,720 )
        sleepTime = 60
      else
        sleepTime = waitT / 2
      end
      sleepTime = 5 if sleepTime < 5
      #DBlog::stoD( "sleepTime = #{sleepTime}" )

      if $recCount == 0
        Thread.new do
          begin
            if EpgLock::lock?() == false
              EpgLock::lock()
              
              #
              #  EPG取得
              #
              if GetEPG.new.start( time_limit ) == true
                #DBlog::stoD( "FilterM.new.update" )
                FilterM.new.update()
              end
              
              #
              #  TS ファイル転送
              #
              if TSFT == true
                FileCopy.new.start( time_limit )
              end
              #
              #  パケットチェック
              #
              if PacketChkRun == true
                PacketChk.new.start( time_limit )
              end
              
              EpgLock::unlock()
            end
          rescue
            EpgLock::unlock()
            puts $!
            puts $@
          end
        end
      end
      
      sleepB( sleepTime )
    end
  end

  #
  #   中断付き sleep( 秒 )
  #
  def sleepB( sec )
    updateChk = DBupdateChk.new
    n = sec / @sleepT
    n.times do |m|
      sleep( @sleepT )
      if updateChk.update?() 
        #DBlog::sto( "タイマー break" ) if $debug == true
        break
      end
    end
  end

  
  #
  #  終了処理未了の後始末
  #
  def tremRec( db, r, text )
    DBlog::stoD("tremRec( #{r[:title]})")
    reserve = DBreserve.new
    reserve.updateStat( db, r[:id], stat: RsvConst::AbNormalEnd, comment: text )
  end

  #
  #  出力先の TSファイル名の生成
  #
  def makeTSfname( data, duration, count = 0 )
    dir = TSDir
    if data[:subdir] != nil and data[:subdir] != ""
      tmp = Commlib::normStr( data[:subdir] )
      dir += "/" + tmp.sub(/^\//,'').sub(/\/$/,'').strip
    end
    unless test( ?d, dir )
      Dir.mkdir( dir )
    end
    st = Time.at( data[:start] ).strftime("%Y-%m-%d_%H:%M")
    fn = sprintf("%s/%s_%d_%s_%s",dir,st,duration,
                 Commlib::normStr( data[:title]),
                 Commlib::normStr( data[:name] ))
    fn += "(#{count})" if count > 0
    fn += ".ts"
    return fn
  end

  #
  #  出力先の TSファイル名の生成(カスタマイズ版)
  #  
  #  %TITLE%    番組タイトル
  #  %ST%       開始日時（ YYYYMMDDHHMM )
  #  %ET%       終了日時（同上）
  #  %BAND%     GR,BS,CS
  #  %CHNAME%   放送局名
  #  %YEAR%     開始年
  #  %MONTH%    開始月
  #  %DAY%      開始日
  #  %HOUR%     開始時
  #  %MIN%      開始分
  #  %SEC%      開始秒
  #  %WDAY%     曜日 0(日曜日)から6(土曜日)
  #  %DURATION%	録画時間（秒）
  #  
  def makeTSfname2( data, duration, count = 0 )

    dir = TSDir
    if data[:subdir] != nil and data[:subdir] != ""
      tmp = Commlib::normStr( data[:subdir] )
      dir += "/" + tmp.sub(/^\//,'').sub(/\/$/,'').strip
    end
    unless test( ?d, dir )
      Dir.mkdir( dir )
    end
    default = "%YEAR%-%MONTH%-%DAY%_%HOUR%:%MIN%_%DURATION%_%TITLE%_%CHNAME%"
    fname = Object.const_defined?(:TSnameFormat) == false ? default : TSnameFormat.dup
    
    st = Time.at( data[:start] )
    et = Time.at( data[:end] )
    
    list = { "%TITLE%"    => data[:title],
             "%CHNAME%"   => data[:name],
             "%ST%"       => st.strftime("%Y%m%d%H%M"),
             "%ET%"       => et.strftime("%Y%m%d%H%M"),
             "%BAND%"     => data[:band],
             "%YEAR%"     => st.strftime("%Y"),
             "%MONTH%"    => st.strftime("%m"),
             "%DAY%"      => st.strftime("%d"),
             "%HOUR%"     => st.strftime("%H"),
             "%MIN%"      => st.strftime("%M"),
             "%SEC%"      => st.strftime("%S"),
             "%WDAY%"     => st.strftime("%w"),
             "%DURATION%" => duration.to_s,
           }
    list.each_pair do |k,v|
      fname.gsub!(/#{k}/,v)
    end
    path = dir + "/" + Commlib::normStr( fname )
    path += "(#{count})" if count > 0
    path += ".ts"
    return path
  end


  #
  #   duration の計算
  #
  def durationCalc( data )
    now = Time.now.to_i
    duration = 0
    
    if data[:start] < now # 途中開始
      duration = data[:end] - now
    else
      duration = data[:duration] + Start_margin
    end
    if data[:jitanExe] == RsvConst::JitanEOn
      duration -= ( Start_margin + Gap_time )
    else
      duration += After_margin
    end
    return duration
  end

  #
  #   終了時間の計算
  #
  def endTImeCalc( data )
    
    endTime = data[:end]
    if data[:jitanExe] == RsvConst::JitanEOn
      endTime -= ( Start_margin + Gap_time )
    else
      endTime += After_margin
    end
    return endTime
  end
  
  #
  #  録画実行
  #
  def recStart( data )

    phch = Commlib::makePhCh( data )
    sid  = [ data[:svid].to_s, "epg" ]
    
    startT = data[:start] - Start_margin

    now = Time.now.to_i
    while now < startT
      now = Time.now.to_i
      sleep(0.1)
    end
    sleeptime = ( data[:tunerNum] - 1).to_f * 0.4 # 開始タイミングをずらす
    sleep( sleeptime )

    retryC = 0
    pid = 0
    begin
      duration = durationCalc( data )
      finish = Time.now + duration
      DBlog::sto("終了予定 = #{finish} : #{data[:title]}")
      fname = makeTSfname2( data, duration, retryC )
      bs = File.basename( fname ).bytesize
      if bs > 255
        DBaccess.new().open do |db|
          DBlog::warn(db, "ファイル名長(#{bs}) > 255")
        end
      end

      duration2 = AutoRecExt == true ? duration * 2 : duration
      waitT = retryC + 2
      if data[:svid] == 101 or data[:svid] == 102 # NHK BS は遅い
        waitT = retryC + 5
      end

      recpt1 = Recpt1.new
      arg = recpt1.makeCmd( phch, duration2, outfn: fname, sid: sid )
      pid = recpt1.recTS( arg, fname, waitT, finish.to_i )
      DBlog::stoD( "pid=#{pid}")
      DBlog::info( nil,"録画開始: #{data[:title]} : pid=#{pid}")
    rescue ExecError
      retryC += 1
      if retryC < 10
        DBlog::warn( nil,"録画開始失敗: #{data[:title]} retry #{retryC}")
        sleep( 1 + sleeptime )
        retry
      else
        DBaccess.new().open do |db|
          text = "録画開始失敗:"
          DBreserve.new.updateStat(db,data[:id],stat: RsvConst::AbNormalEnd, comment: text )
          text += " #{data[:title]}"
          DBlog::warn(db, text)
        end
        return
      end
    rescue
      puts $!
      puts $@
    end
    
    DBaccess.new().open do |db|
      DBreserve.new.updateStat(db,data[:id],
                               stat: RsvConst::RecNow,
                               recpt1pid: pid,
                               fname: File.basename(fname) )
    end

    endTime1 = data[:end]          # 終了予定時間
    endTime2 = endTImeCalc( data ) # 終了予定時間(マージン込)

    #
    #  終了 ARE_sampling_time秒前に EPGデータ 取得
    #
    if AutoRecExt == true
      
      Thread.new(pid) do |pid|
        begin
          Thread.current[:oldet2] = endTime2
          ( endTime1, endTime2 ) = ReservExt( fname,pid,endTime1,endTime2, data )
          if Thread.current[:oldet2] > endTime2
            DBlog::stoD("Warn: 終了時間が早まりました。 #{Time.at(endTime2).to_s}")
          end
          if Thread.current[:oldet2] != endTime2
            DBlog::stoD("ReservExt endTime diff ")
            raise ReservExtOn
          end
        rescue ReservExtOn
          DBlog::stoD("retry")
          retry
        rescue => e
          Commlib::errPrint("Error: ReservExt()", $!, e )
        end

        #
        #  デバックの為のデータ書き換え(録画開始後のタイトル変更)
        #
        # DBaccess.new.open(tran: true ) do |db|
        #   reserve = DBreserve.new
        #   programs = DBprograms.new
        #   row = reserve.select( db, stat: RsvConst::RecNow )
        #   row.each do |r|
        #     printf("# %d %s\n",r[:id], r[:title])
        #     row2 = programs.select( db, chid: r[:chid], evid: r[:evid] )
        #     row2.each do |r2|
        #       printf("> %d %s\n",r2[:id], r2[:title])
        #       title = r2[:title] + " TEST"
        #       db.execute( "update programs set title = ? where id = ?", title,r2[:id] )
        #     end
        #   end
        # end
        # FilterM.new.update() # 再スケージュール
        
      end
    end

    #
    #  終了待ち
    #
    Thread.new(pid) do |pid|
      orgEndTime = endTime2
      DBlog::stoD("予定終了時間 #{pid} #{Time.at(endTime2).to_s}")
      while Commlib::sleepTimeBin( endTime2 )
        if orgEndTime != endTime2
          DBlog::warn(nil,"録画中 終了時間変更 #{data[:title]} #{pid} #{Time.at(orgEndTime)} -> #{Time.at(endTime2)}")
          orgEndTime = endTime2
        end
      end
      if Commlib::alivePid?( pid )
        DBlog::stoD("終了時間到達 #{pid} #{Time.now.to_s}")
        begin
          Process.kill(:KILL, pid)
        rescue
        end
      end
    end
    
    
    $rec_pid[ pid ] = true
    DBlog::stoD( "waitpid start #{pid}")
    Process.waitpid( pid )
    $rec_pid.delete( pid )
    DBlog::stoD( "waitpid end #{pid}")
    
    reserve = DBreserve.new
    DBaccess.new.open(tran: true ) do |db| # 中止の場合は競争なので、要tran
      if ( sa = ( Time.now - finish )) < -5
        row = reserve.select( db, id: data[:id] )
        if row != nil and row[0][:stat] == RsvConst::RecNow
          text = sprintf("録画時間未達: (%d秒)",sa.to_i )
          DBlog::error(db,"#{text} #{data[:title]}")
          reserve.updateStat(db,data[:id],stat: RsvConst::AbNormalEnd, comment: text )
        end
      else
        reserve.updateStat( db, data[:id],
                            stat:     RsvConst::NormalEnd,
                            ftp_stat: RsvConst::Off,
                            fname:    File.basename(fname),
                          )
        DBlog::info(db, "録画終了: #{data[:title]}")
        DBupdateChk.new.touch()          
      end
    end

    #
    # 番組途中のタイトル変更に伴う、TSファイル名変更
    #
    DBaccess.new.open( tran: true ) do |db|
      row = reserve.selectSP( db, id: data[:id] )
      if row == nil or row.size == 0
        pp "error"
      else
        r = row[0]
        fname2 = makeTSfname2( r, duration, retryC )
        if fname2 != fname
          DBlog::sto( "出力ファイル名を変更します。#{File.basename(fname)} -> #{File.basename(fname2)}")
          if test( ?f, fname )
            File.rename( fname, fname2 )
            reserve.updateStat( db, r[:id], fname: File.basename(fname2) )
          else
            pp "Error: file not found (#{fname})"
          end
        end
      end
    end
    
  end


  #
  #  番組終了間際の EPG取得 -> 延長
  #
  def ReservExt(tsfname, pid, endTime1, endTime2, data )
    newEndTime1 = endTime1
    newEndTime2 = endTime2
    epgTime = endTime1 - ARE_sampling_time
    if ( epgTime - Time.now.to_i ) > 0
      DBlog::stoD("予定EPG取得時間 #{pid} #{Time.at(epgTime).to_s}")
      while Commlib::sleepTimeBin( epgTime ) 
      end
      if Commlib::alivePid?( pid )
        DBlog::stoD("EPG取得時間到達 #{pid} #{Time.now.to_s}")
        phch = Commlib::makePhCh( data )
        jsonFname = JsonDir + "/#{phch}_#{pid}.json"

        DBlog::stoD("epgdump start #{pid}")
        args = [ "json", tsfname, jsonFname] + ARE_epgdump_opt
        dumppid = spawn( Epgdump, *args, :err=>:out )
        Process.waitpid( dumppid )
        if $debug == true
          tmp = chkJsonEvid( jsonFname, data[:evid], endTime1, false )
          #jsonFname = tmp # debug時
        end
        DBlog::stoD("epgdump end   #{pid}")

        GetEPG.new.tailEpgStart( jsonFname, phch )

        reserve = DBreserve.new
        programs = DBprograms.new

        st = Time.now.to_i - 3600 * 24 # evid が重複する可能性があるので時間で制限
        DBaccess.new().open do |db|
          row = reserve.select( db, chid: data[:chid], evid: data[:evid], tstart: st )
          if row.size > 0
            newEndTime1 = row[0][:end]
            newEndTime2 = endTImeCalc( row[0] )
            DBlog::stoD("newEndTime = #{Time.at( newEndTime2)} #{pid}" )
            if newEndTime2 != endTime2
              DBlog::stoD("*** 終了時間変更 *** #{Time.at(newEndTime2).to_s} #{pid}")
            end
          end
        end
      end
    end
    return [ newEndTime1, newEndTime2 ]
  end

  #
  #  EPG json ファイル中に指定した event_id が存在するかチェック
  #
  def chkJsonEvid( fname, evid, endTime1, debug = false )
    DBlog::stoD("chkJsonEvid( #{fname}, #{evid} #{Time.at(endTime1)} )")
    flag = false
    et = 0
    fname2 = fname + ".tmp"
    File.open( fname, "r" ) do |fp|
      str = fp.read
      data = JSON.parse(str)
      data.each do |ch|
        if ch[ "programs" ] != nil
          ch[ "programs" ].each do |prog|
            if prog[ "event_id" ] == evid
              flag = true
              et = (prog[ "end" ] / 1000 ).to_i
              if debug == true
                if rand(3) > 0                              # 2/3 の確率で
                  prog[ "end" ] = ( endTime1 + 180 ) * 1000 # 3分延長
                  
                  DBlog::stoD("chkJsonEvid() *** 延長 ***  #{evid} #{Time.at(endTime1)}")
                else
                  DBlog::stoD("chkJsonEvid() 延長なし  #{evid}")
                end
              end
            end
          end
        end
      end

      if debug == true        # debug 用
        File.open( fname2, "w" ) do |fp|
          JSON.dump( data, fp)
        end
      end
    end
    
    if flag == false
      DBlog::stoD("chkJsonEvid() *** NG evid not found ***  #{evid}")
    else
      if endTime1 != et
        DBlog::stoD("chkJsonEvid() *** NG diff *** #{evid} #{Time.at(et).to_s}")
      else
        DBlog::stoD("chkJsonEvid() OK #{evid} #{et} #{Time.at(et).to_s}")
      end
    end
    if debug == true
      return fname2
    end
    return fname
  end
  
end
