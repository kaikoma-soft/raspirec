#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  予約関係
#


class Reservation

  def initialize( params = nil )
    @params = params if params != nil
    DBlog::sto("Reservation new" ) if $debug == true
    @ts = Time.now
  end

  
  #
  #  予約のチェック
  #
  def check( db )
    @ts = Time.now
    #ppp("Reservation.check() start")
    ts1 = Time.now
    reserve = DBreserve.new
    programs = DBprograms.new

    row1 = reserve.selectSP( db, tend: Time.now.to_i )
    #ppp("Reservation.check() P1")
    row1.each do |r|
      row2 = programs.selectSP( db, chid: r[:chid], evid: r[:evid], skip: 0 )
      if row2.size == 0
        if r[:stat] != RsvConst::RecStop
          (day, time, w) = Commlib::stet_to_s( r[:start], r[:end] )
          come1 = "番組消失"
          come2 = sprintf("%s: %s %s %s %s", come1, day, time, r[:name],r[:title])
          DBlog::warn(db, come2 )
          reserve.updateStat( db,r[:id],stat: RsvConst::RecStop, comment: come1 )
        end
      else
        row2.each do |pro|
          if pro[:start] != r[:start] or pro[:end] != r[:end]
            come1 = "時間変更"
            (day, time, w) = Commlib::stet_to_s( pro[:start], pro[:end] )
            come2 = sprintf("%s: %s %s %s %s",come1, day, time, r[:name],r[:title])
            DBlog::atte(db, come2 )
            reserve.updateT( db, pro[:start], pro[:end], pro[:duration],r[:id] )
          end

          if pro[:title] != r[:title]
            come1 = "タイトル変更"
            (day, time, w) = Commlib::stet_to_s( pro[:start], pro[:end] )
            come2 = sprintf("%s: %s %s %s %s -> %s",come1, day, time, r[:name],r[:title],pro[:title])
            DBlog::atte(db, come2 )
            reserve.updateA( db, r[:id], title: pro[:title] )
          end
        end
      end
    end

    #ppp("Reservation.check() P2")
    #
    # 消失からの復帰
    #
    row1 = reserve.selectSP( db, stat: RsvConst::RecStop )
    row1.each do |r|
      row2 = programs.selectSP( db, chid: r[:chid], evid: r[:evid], skip: 0 )
      if row2.size > 0
        row2.each do |pro|
          come1 = "番組復帰"
          (day, time, w) = Commlib::stet_to_s( pro[:start], pro[:end] )
          come2 = sprintf("%s: %s %s %s %s",come1, day, time, r[:name],r[:title])
          DBlog::atte(db, come2 )
          reserve.updateStat( db,r[:id],stat: RsvConst::Normal, comment: "" )
        end
      end
    end

    #ppp("Reservation.check() P3")
    #
    #  録画終了したものの title の hash 値を設定
    #
    reserve.titleHash( db )

    #ppp("Reservation.check() P4")
    #
    # 重複 check
    #
    dupchk = reserve.selectSP( db, tend: Time.now.to_i, order: "order by start" )
    dupchk.each do |r|
      next if r[:dedupe] == RsvConst::Off
      next if r[:type] == RsvConst::Manual
      title = r[:title].sub(/【再】/,'').sub(/^\[[無新]\]/,'')
      titleH = Commlib::makeHashKey( title )
      row1 = reserve.select( db, stat: RsvConst::NormalEnd, recpt1pid: titleH.to_i )
      
      if row1 == nil or row1.size == 0
        if r[:stat] == RsvConst::NotUseA
          come1 = "重複無効を解除"
          (day, time, w) = Commlib::stet_to_s( r[:start], r[:end] )
          come2 = sprintf("%s %s %s %s %s",come1, day, time, r[:name],r[:title])
          DBlog::atte(db, come2 )
          reserve.updateStat( db,r[:id],stat: RsvConst::Normal, comment: come1 )
        end
      else
        r2 = row1.first
        if ( r[:stat] == RsvConst::Normal or r[:stat] == RsvConst::Conflict ) and r2[:title] == title
          come1 = "重複の為無効化:"
          (day, time, w) = Commlib::stet_to_s( r[:start], r[:end] )
          come2 = sprintf("%s %s %s %s %s",come1, day, time, r[:name],r[:title])
          DBlog::atte(db, come2 )
          come1 = "重複"
          reserve.updateStat( db,r[:id],stat: RsvConst::NotUseA, comment: come1 )
        end
      end
    end

    #
    # 予約テーブルのtitle のchk
    #
    reserve.titleChk( db )
    
    #ppp("Reservation.check() P5")

    TunerAssignNew.new.schedule2(db)

    #ppp("Reservation.check() end")
  end
    
  #
  #  予約の新規登録
  #
  def add( pid )
    subdir = @params["dir"] == nil ? nil : @params["dir"]
    jitan  = @params["jitan"] == nil ? 1 : 0

    programs = DBprograms.new
    reserve  = DBreserve.new
    DBaccess.new().open( tran: true ) do |db|
      if ( r = programs.selectSP( db, proid: pid )) != nil and r.size > 0
        r[0][:subdir]    = subdir
        r[0][:jitan]     = jitan
        r[0][:jitanExe]  = RsvConst::JitanOff
        r[0][:id]        = nil
        r[0][:keyid]     = 0
        #r[0][:use]       = 0
        r[0][:comment]   = ""
        r[0][:type]      = 0
        r[0][:stat]      = 0
        r[0][:category]  = r[0][:categoryA][0][0]
        reserve.insert( db, r[0] )
      end
      self.check( db )
    end
    
  end

  #
  #  予約の削除
  #
  def del( rid )

    reserve  = DBreserve.new
    DBaccess.new().open( tran: true ) do |db|
      reserve.delete( db, id: rid )
      self.check( db )
    end
    
  end
  
  #
  #  予約内容の変更
  #  {"use"=>"on", "jitan"=>"on", "dir"=>"aaa" }
  def mod( rid )

    DBaccess.new().open( tran: true ) do |db|
      use   = @params["use"] == "on" ? RsvConst::NotUse : RsvConst::Normal
      jitan = @params["jitan"] == "on" ? 0 : 1
      dir   = @params["dir"] 
      DBreserve.new.updateS( db, rid, use, jitan, dir )
      self.check( db )
    end
  end


  #
  #  録画中を停止
  #
  def stop( rid )

    reserve  = DBreserve.new
    DBaccess.new().open( tran: true ) do |db|
      row = reserve.select( db, id: rid )
      row.each do |r|
        if r[:stat] == RsvConst::RecNow
          if r[:recpt1pid] != nil and r[:recpt1pid] > 0
            DBlog::sto("kill #{r[:recpt1pid]}")
            begin
              Process.kill(:HUP, r[:recpt1pid] );
            rescue Errno::ESRCH, Errno::EPERM 
              puts $!
              puts $@
            end
          end
          DBlog::info(db,"録画中止: #{r[:title]}")
          reserve.updateStat( db,r[:id],stat: RsvConst::RecStop2 )
        end
      end
      self.check( db )
    end
  end
  
  
end

if File.basename($0) == "Reservation.rb"

  base = File.dirname( $0 )
  [ ".", "..","src", base ].each do |dir|
    if test( ?f, dir + "/require.rb")
      $: << dir
      $baseDir = dir
    end
  end

  flag = false
  if Object.const_defined?(:RewriteConst) == false
    Object.const_set( :RewriteConst, true )
    flag = true
  end
  require 'require.rb'

  if flag == false
    $tunerArray = TunerArray.new
    a = Reservation.new( ARGV[0].to_i )
    a.checkBG().join
  end
end
