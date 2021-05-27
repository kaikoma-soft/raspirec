#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  タイマー
#

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
    now = Time.now.to_i
    readyTime = now + 20
    nextRecTime = now + 3600 * 24
    queue = []
    recC = 0 
    
    DBaccess.new().open do |db|
      db.transaction do
        row = reserve.selectSP( db, stat: RsvConst::Normal, order: "order by start" )
        row.each do |r|
          next if r[:stat] == RsvConst::NotUse
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
        #epgLastTime = keyval.select( db, Const::LastEpgTime  )

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
            if $recCount == 0
              if ( Time.now - lastTimeD ) > ( 6 * 3600 )
                $mutex.synchronize do
                  DBaccess.new().open do |db|
                    db.transaction do
                      DiskKeep.new.start(db)
                    end
                  end
                end
                lastTimeD = Time.now
              end
            end
            sleep( 3600 )
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
      DBlog::stoD( "sleepTime = #{sleepTime}" )

      if $recCount == 0
        Thread.new do
          begin
            if EpgLock::lock?() == false
              EpgLock::lock()
              
              #
              #  EPG取得
              #
              if GetEPG.new.start( time_limit ) == true
                DBlog::stoD( "FilterM.new.update" )
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
        DBlog::sto( "タイマー break" ) if $debug == true
        break
      end
    end
  end

  
  #
  #  終了処理未了の後始末
  #
  def tremRec( db, r, text )
    DBlog::sto("tremRec( #{r[:title]})")
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
  #  recpt1 のチャンネル指定
  #
  def makeCh( data )
    r = []
    phch = Commlib::makePhCh( data )
    r << phch
    r += [ "--sid", data[:svid].to_s + ",epg" ]
    r
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
  #  録画実行
  #
  def recStart( data )

    ch = makeCh( data )
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
      arg = [ ]
      arg += Recpt1_opt if Recpt1_opt != nil
      arg += ch + [ duration.to_s, fname ]
      waitT = retryC + 2
      if data[:svid] == 101 or data[:svid] == 102 # NHK BS は遅い
        waitT = retryC + 5
      end

      pid = Recpt1.new.recTS( arg, fname, waitT )
      $mutex.synchronize do
        #DBlog::sto( "pid=#{pid}")
        DBlog::info( nil,"録画開始: #{data[:title]} : pid=#{pid}")
      end
    rescue ExecError
      retryC += 1
      if retryC < 10
        $mutex.synchronize do
          DBlog::warn( nil,"録画開始失敗: #{data[:title]} retry #{retryC}")
        end
        sleep( 1 + sleeptime )
        retry
      else
        $mutex.synchronize do
          DBaccess.new().open do |db|
            text = "録画開始失敗:"
            DBreserve.new.updateStat(db,data[:id],stat: RsvConst::AbNormalEnd, comment: text )
            text += " #{data[:title]}"
            DBlog::warn(db, text)
          end
        end
        return
      end
    rescue
      puts $!
      puts $@
    end
    
    $mutex.synchronize do
      DBaccess.new().open do |db|
        DBreserve.new.updateStat(db,data[:id],
                                 stat: RsvConst::RecNow,
                                 recpt1pid: pid,
                                 fname: File.basename(fname) )
      end
    end
    
    $rec_pid[ pid ] = true
    #DBlog::sto( "waitpid start #{pid}")
    Process.waitpid( pid )
    $rec_pid.delete( pid )
    #DBlog::sto( "waitpid end #{pid}")
    
    $mutex.synchronize do
      DBaccess.new().open do |db|
        db.transaction do
          if ( sa = ( Time.now - finish )) < -5
            reserve = DBreserve.new
            row = reserve.select( db, id: data[:id] )
            if row[0][:stat] == RsvConst::RecNow
              text = sprintf("録画時間未達: (%d秒)",sa.to_i )
              DBlog::warn(db,"#{text} #{data[:title]}")
              DBreserve.new.updateStat(db,data[:id],stat: RsvConst::AbNormalEnd, comment: text )
            end
          else
            DBreserve.new.updateStat( db, data[:id],
                                      stat:     RsvConst::NormalEnd,
                                      ftp_stat: RsvConst::Off,
                                      fname:    File.basename(fname),
                                    )
            DBlog::info(db, "録画終了: #{data[:title]}")
            DBupdateChk.new.touch()          
          end
        end
      end
    end
  end



end
