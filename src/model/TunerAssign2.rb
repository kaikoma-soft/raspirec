#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  チューナーの割当
#

class TunerAssignNew

  def initialize( )
    DBlog::sto("TunerAssignNew new" ) if $debug == true
  end

  #
  #  割り当て実行
  #
  def schedule( db = nil, debug: false )
    if db == nil
      DBaccess.new().open( tran: true ) do |db|
        schedule2( db, debug: debug )
      end
    else
      schedule2(db, debug: debug )
    end
  end

  #
  #  移動対象のサーチ
  #
  def moveSearch(ta, r)
    band = r[:band2]
    st   = r[:start2]
    et   = r[:end3]           # 時短
    ret = []
    ta.each do |tun|
      if tun.band[ band ] == true
        tun.data.each_with_index do |res,n|
          if res[:end3].between?( st,et ) or 
            res[:start2].between?( st,et ) or
            st.between?( res[:start2], res[:end3] ) # 衝突してるもの
            if n == 0          # 先頭
              pet = 0
            else
              pet = tun.data[n-1][:end3]
            end
            if tun.data[n+1] == nil # 次が無い
              nst = et + 60
            else
              nst = tun.data[n+1][:start2]
            end
            # 移動させた後、入るか？
            if ( pet < st) and ( et < nst )
              ret << res
            end
          end
        end
      end
    end
    return ret
  end

  def jitan_reg( ta, res )
    (tuner, target ) = ta.insert_jitan?( res )
    if tuner != nil
      res[:tunerNum] = tuner.num[ res[:band2] ]
      if target.class == Array
        target.each do |t1|
          t1[:jitanExe] = RsvConst::JitanEOn
        end
      end
      tuner.addData( res )
      return true
    end  
    return false
  end

  def schedule2( db, debug: false)
    DBlog::sto("TunerAssignNew.schedule2() start") if $debug == true
    ts = Time.now
    
    reserve = DBreserve.new
    ta = $tunerArray
    ta.allClear()
    
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
      r[:stat] = RsvConst::Normal if r[:stat] != RsvConst::RecNow
      r[:start2]   = r[:start] - Start_margin # マージン込
      r[:end2]     = r[:end] + After_margin   # マージン込
      if r[:jitan] == 0
        r[:end3]   = r[:end] - ( Start_margin + Gap_time ) # 時短時
      else
        r[:end3]   = r[:end2]
      end
      r[:jitanExe] = RsvConst::JitanEOff
      r[:band2]    = r[:band] == Const::GR ? Const::GR : Const::BSCS
      r[:assign]   = false      # 割り当て済みフラグ
      r[:comment]  = ""
    end

    #
    #  pass 2 : 時短無しでチューナーの割り当て
    #
    row1.each do |r|
      if ( tuner = ta.insert?( r )) != nil
        r[:assign] = true
        r[:tunerNum] = tuner.num[ r[:band2] ]
        tuner.addData( r )
      end
    end

    #
    #  pass 3 : 時短有りでチューナーの割り当て
    #
    row1.each do |r|
      if r[:assign] == false
        (tuner, target ) = ta.insert_jitan?( r )
        if tuner != nil
          r[:assign] = true
          r[:tunerNum] = tuner.num[ r[:band2] ]
          if target.class == Array
            target.each do |t1|
              t1[:jitanExe] = RsvConst::JitanEOn
            end
          end
          tuner.addData( r )
        end
      end
    end

    
    #
    #  pass 4 : それでも残ったら、同じ時間帯の別予約をずらして入るか
    #
    row1.each do |r|
      if r[:assign] == false
        # 移動対象の候補を検索
        list = moveSearch(ta, r)
        list.each do |res|
          # 移動先が見つかれば、移動して、自分を登録
          oldnum = res[:tunerNum]
          if jitan_reg( ta, res ) == true
            ta.deleteData( res[:band2], oldnum, res[:id] )
            if jitan_reg( ta, r ) == true
              r[:assign] = true
              break
            else
              DBlog::sto("Error: jitan_reg() is fail")
            end
          end
        end
      end
    end
    
    #
    #  pass 5 : 残ったものを Conflict に
    #
    row1.each do |r|
      if r[:assign] == false
        # pp "Conflict #{r[:title]}  #{r[:tunerNum]}"
        r[:comment] = "チューナー不足"
        r[:stat] = RsvConst::Conflict
        r[:tunerNum] = 1
      end
    end
    
    #
    #  チューナー数の最大値のチェック
    #
    if Total_tuner_limit.class == Integer
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
            t[:tunerNum] = 1
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
        n2[:stat]  != o[:stat] or
        n2[:comment] != o[:comment]
        reserve.updateJ( db, n2[:jitanExe], n2[:tunerNum], n2[:stat],n2[:comment],n2[:id] )
      end
    end
    
    DBupdateChk.new.touch       # DB の更新を通知

    #
    #  時間が重なっていないかの最終チェック
    #
    if debug == true
      DBlog::sto("final check")
      ta = $tunerArray
      ta.allClear()
      row1 = reserve.selectSP( db, stat: RsvConst::ActStat )
      row1.each do |r|
        band = r[:band] == Const::GR ? Const::GR : Const::BSCS
        tnum = r[:tunerNum]
        if r[:stat] == RsvConst::Conflict
          band = :short
        end
        if ta.addData( band, tnum, r ) == false
          DBlog::sto("Error: TunerArray::addData()")
        end
      end

      ta.each do |tun|
        tun.sortS
        tun.data.each_with_index do |res,n|
          break if tun.data[n+1] == nil
          et = res[:end] + After_margin
          if res[:jitanExe] == RsvConst::JitanEOn
            et = res[:end] - ( Start_margin + Gap_time ) # 時短時
          end
          nst = tun.data[n+1][:start] - Start_margin
          if et > nst
            DBlog::sto("最終チェック error #{res[:start]} #{res[:title]}")
          end
        end
      end
    end
    DBlog::sto("TunerAssignNew.schedule2() end #{Time.now - ts}") if $debug == true
    
  end


  #
  #  デバック用
  #
  def dump( row, n )
    dump2( row,  31945, n )
  end
  
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

  def count( row1 )
    sumi = mi = 0
    row1.each do |r|
      if r[:assign] == false
        mi +=1
      else
        sumi += 1
      end
    end
    printf("済み = %d, 未 = %d\n",sumi,mi )
  end
  
end





if File.basename($0) == "TunerAssign2.rb"
  base = File.dirname( $0 )
  [ ".", "..","src", base ].each do |dir|
    if test( ?f, dir + "/require.rb")
      $: << dir
      $baseDir = dir
    end
  end

  if Object.const_defined?(:RewriteConst) == false
    Object.const_set( :RewriteConst, true )
  end
  require 'require.rb'

  $tunerArray = TunerArray.new
  ta = TunerAssignNew.new

  ta.schedule( nil, debug: true )

  exit
  
end

