#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  チューナーの割当
#

class Tuner

  def assign( flag, t, tuner )
    if flag == :set
      1.upto(99) do |n|
        if tuner[ t[:band2]][n] == nil
          tuner[ t[:band2]][n] = true
          return n
        end
      end
    else
      tuner[ t[:band2] ][ t[:tunerNum] ] = nil
    end
  end

  #
  #   debug用
  #
  def print( times, row1 )

    times.keys.sort.each do |time|
      t2 = Time.at( time )
      row1.each do |t|
        if time == t[:start2] or time == t[:end2]
          type = time == t[:start2] ? "start" : "end"
          printf("%s %-5s   %d %d %d %d %s\n",
                 t2, type,t[:stat],t[:tunerNum], t[:jitan], t[:jitanExe], t[:title] )
        end
      end
    end
  end


  #
  # 指定したバンド、チューナー、開始時間以後の次の予約時間を返す
  #
  def search_free( band, tuner, start, row1 )
    t = nil
    row1.each do |r|
      if r[:band2] == band
        if r[:tunerNum] == tuner
          if r[:start2] > start
            if t == nil or t > r[:start2]
              t = r[:start2]
            end
          end
        end
      end
    end
    t
  end
  
  #
  #  指定したタイミング直後に終了するものを返す
  #
  def search_precede( band, start, row1, sort: nil  )
    r = []
    sa = Start_margin + After_margin
    row1.each do |r2|
      next if r2[:band2] != band
      if ( r2[:end2] - start ) == sa
        r << r2
      end
    end
    if sort != nil
      r.sort! do |a,b|
        a2 = a[:chid] == sort ? 10 : 0
        b2 = b[:chid] == sort ? 10 : 0
        a2 <=> b2
      end
    end
    r
  end

  #
  #  割り当て実行
  #
  def schedule( db = nil, debug: false )
    if db == nil
      DBaccess.new().open do |db|
        db.transaction do
          schedule2( db, debug: debug )
        end
      end
    else
      schedule2(db, debug: debug )
    end
  end


  #
  #  対象 t に近いものを row から探す。
  #
  def searchNear( t, row )
    ret = []
    prevP = nil
    nextP = nil
    row.each do |r|
      next if t == r
      next if t[:band2] != r[:band2]
      if t[:start].between?( r[:start], r[:end] ) or
        t[:end].between?( r[:start], r[:end] ) 
        ret << r
      end
    end
    return ret
  end

  #
  #  時短実行フラグを立てる。
  #
  def jitanExeEOn( target )
    target[:jitanExe] = RsvConst::JitanEOn
    target[:end2] = target[:end]  - ( Start_margin + Gap_time )
  end
      

  #
  #  対象 t が別チューナーに移動出来る隙間があるか？
  #
  def canMove( t, row, max )
    tuner = {}
    row.each do |r|
      if t[:band2] == r[:band2] and r[:tunerNum] != t[:tunerNum]
        if r[:tunerNum] <= max
          tuner[ r[:tunerNum] ] ||= []
          tuner[ r[:tunerNum] ] << r
        end
      end
    end
    ret = nil
    tuner.keys.each do |tun|
      prev = nil
      tuner[ tun ].each do |r|
        if prev != nil
          if t[:start].between?( prev[:end], r[:start] ) and
            t[:end].between?( prev[:end], r[:start] ) and
            prev[:jitan] == RsvConst::JitanOn
            #printf("bingo %s %s\n",Time.at(prev[:end]), Time.at(r[:start]) )
            ret = prev
          end
        end
        prev = r
      end
    end
    return ret
  end

  def dump( row, n )
    dump2( row,  31945, n )
  end
  #
  #  デバック用
  #
  def dump2( row, evid, n )
    row.each do |r|
      if r[:evid] == evid
        time = Time.at(r[:start])
        ts2  = Time.at(r[:start2])
        te2  = Time.at(r[:end2])
        str = "#{n} #{time} #{r[:name]} #{r[:title]} #{r[:tunerNum]} #{r[:jitanExe]} #{ts2} #{te2}"
        puts( str )
      end
    end
  end
  
  def schedule2(db, debug: false)

    now = Time.now.to_i
    reserve = DBreserve.new
    times = {}
    tuner = { Const::GR => [],
              Const::BSCS => [],
            }
    #t = Time.local( 2019, 7, 31, 21, 00 ).to_i
    #row1 = reserve.selectSP( db, tend: t )
    row1 = reserve.selectSP( db, stat: RsvConst::ActStat )

    # 後で比較する為にコピー
    row1_old = []
    row1.each do |r|
      row1_old << r.dup
    end

    #
    # pass 1 : 前準備
    #
    row1.each do |r|
      r[:start2]   = r[:start] - Start_margin
      r[:end2]     = r[:end] + After_margin 
      r[:jitanExe] = RsvConst::JitanEOff
      r[:band2]    = r[:band] == Const::GR ? Const::GR : Const::BSCS
      
      times[ r[:start2] ] ||= []
      times[ r[:start2] ] << r
      times[ r[:end2] ] ||= []
      times[ r[:end2] ] << r
    end


    #
    #  pass 2 : 時短無しでチューナーの仮割当
    #
    timesA = times.keys.sort
    timesA.each_with_index do |time,n|
      times[ time ].sort do |a,b|
        b[:duration] <=> a[:duration]
      end.each do |r|
        if time == r[:start2]
          r[:tunerNum] = assign( :set, r, tuner )
          r[:stat] = RsvConst::Normal if r[:stat] != RsvConst::RecNow
          r[:jitanExe] == RsvConst::JitanEOff
        end
        if time == r[:end2] 
          assign( :reset, r, tuner )
        end
      end
    end


    #
    #  pass 3 : チュナー不足があれば、前を時短して入れる。
    #
    row1.each do |r|
      max = r[:band] == Const::GR ? GR_tuner_num : BSCS_tuner_num
      if r[:tunerNum] > max
        r2 = search_precede( r[:band2], r[:start2], row1, sort: r[:chid] )
        r2.each do |r3|
          next if r3[:jitan] != RsvConst::JitanOn
          nextT = search_free( r3[:band2], r3[:tunerNum], r[:start2], row1 )
          if nextT == nil or nextT > r[:end2]   # 十分余裕
            jitanExeEOn( r3 )
            r[:tunerNum] = r3[:tunerNum]
            r[:stat] = RsvConst::Normal if r[:stat] != RsvConst::RecNow
          elsif nextT > ( r[:end2] - ( After_margin + Gap_time + Start_margin))
            # 自分を時短してギリギリ
            if r[:jitan] == RsvConst::JitanOn
              jitanExeEOn( r3 )
              jitanExeEOn( r )
              r[:tunerNum] = r3[:tunerNum]
              r[:stat] = RsvConst::Normal if r[:stat] != RsvConst::RecNow
            end
          end
        end
      end
    end

    #
    #  pass 4 : それでも駄目なら、他者を動かしたら入るか
    #
    row1.each do |r|
      max = r[:band] == Const::GR ? GR_tuner_num : BSCS_tuner_num
      if r[:tunerNum] > max
        row2 = searchNear( r, row1 )
        moveF = false
        row2.each do |r2|
          if ( target = canMove( r2, row1, max )) != nil
            jitanExeEOn( target )
            r2[:tunerNum] = target[:tunerNum]
            moveF = true
            break
          end
        end
        if moveF == true 
          if ( target = canMove( r, row1, max )) != nil
            jitanExeEOn( target )
            r[:tunerNum] = target[:tunerNum]
          end
        end
      end
    end

    #
    #  pass 4 : 移動によって時短が必要になった所にフラグを立てる
    #
    tuner = {}
    row1.each do |r|
      b = r[:band2]
      t = r[:tunerNum]
      tuner[b] ||= {}
      tuner[b][t] ||= []
      tuner[b][t] << r
    end
    tuner.keys.each do |b|
      tuner[b].each_pair do |k,v|
        v.each_with_index do |r,n|
          next if v[n+1] == nil
          s = v[n+1]
          if r[:end2] > s[:start2]
            if s[:jitan] == RsvConst::JitanOn
              # te2 = Time.at( r[:end2] )
              # ts2 = Time.at( s[:start2] )
              # pp "#{r[:title]} -> #{s[:title]} #{te2} #{ts2}"
              jitanExeEOn( r )
            end
          end
        end
      end
    end

    
    #
    #  不足を検出
    #
    row1.each do |r|
      r[:stat] = RsvConst::Normal if r[:stat] == RsvConst::Conflict
    end
    row1.each do |r|
      bandmax = r[:band] == Const::GR ? GR_tuner_num : BSCS_tuner_num
      come = ""
      if r[:tunerNum] > bandmax
        r[:comment] = "チューナー不足"
        r[:stat] = RsvConst::Conflict
      end
    end

    #
    #  チューナー数の最大値のチェック
    #
    row1.each do |t1|
      next if t1[:stat] == RsvConst::Conflict
      st = t1[:start] + 1
      tmp = []
      row1.each do |t2|
        next if t2[:stat] == RsvConst::Conflict
        if st.between?( t2[:start], t2[:end] )
          tmp << t2
        end
      end
      tmp.each_with_index do |t,n|
        if n > ( Total_tuner_limit - 1 )
          t[:comment] = "トタール制限"
          t[:stat] = RsvConst::Conflict
        end
      end
    end

    
    #
    #  最後にチューナー毎に時間が重複してないかのチェック
    #
    tuner = {}
    row1.each do |r|
      b = r[:band2]
      t = r[:tunerNum]
      tuner[b] ||= {}
      tuner[b][t] ||= []
      tuner[b][t] << r
    end
    tuner.keys.each do |b|
      tuner[b].each_pair do |k,v|
        v.each do |r|
          v.each do |t|
            next if r == t
            if r[:start2].between?( t[:start2], t[:end2] ) or
              r[:end2].between?( t[:start2], t[:end2] )
              time = Time.at(r[:start]).strftime("%m/%d %H:%M")
              str = " #{time} #{r[:name]} #{r[:tunerNum]} #{r[:title]}"
              DBlog::error(db,"予約時間重複あり #{str}")
            end
          end
        end
      end
    end
  
    #
    #  変更箇所の DB を更新
    #
    row1_old.each_with_index do |o,n|
      n2 = row1[n]
      if n2[:tunerNum] != o[:tunerNum] or
        n2[:jitanExe]  != o[:jitanExe] or
        n2[:stat]  != o[:stat]
        reserve.updateJ( db, n2[:jitanExe], n2[:tunerNum], n2[:stat],n2[:comment],n2[:id] )
      end
    end

    print( times, row1 ) if debug == true
    
    DBupdateChk.new.touch       # DB の更新を通知
  end
  
end
