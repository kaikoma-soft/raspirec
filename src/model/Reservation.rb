#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  予約関係
#


class Reservation

  def initialize( params = nil )
    @params = params if params != nil
  end

  #
  #  予約のチェック
  #
  def check( db )
    now = Time.now.to_i
    reserve = DBreserve.new
    programs = DBprograms.new
    row1 = reserve.selectSP( db, stat: RsvConst::WaitStat )
    dupchk = []
    row1.each do |r|
      next if r[:stat] == RsvConst::NotUse
      if r[:dedupe] == RsvConst::Dedupe
        dupchk << r
      end
      row2 = programs.selectSP( db, chid: r[:chid], evid: r[:evid], skip: 0 )
      if row2.size == 0
        (day, time, w) = Commlib::stet_to_s( r[:start], r[:end] )
        come1 = "番組消失"
        come2 = sprintf("%s: %s %s %s %s", come1, day, time, r[:name],r[:title])
        DBlog::warn(db, come2 )
        reserve.updateStat( db,r[:id],stat: RsvConst::RecStop, comment: come1 )
      else
        pro = row2[0]
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

    #
    # 消失からの復帰
    #
    row1 = reserve.selectSP( db, stat: RsvConst::RecStop )
    row1.each do |r|
      row2 = programs.selectSP( db, chid: r[:chid], evid: r[:evid], skip: 0 )
      if row2.size > 0
        pro = row2[0]
        come1 = "番組復帰"
        (day, time, w) = Commlib::stet_to_s( pro[:start], pro[:end] )
        come2 = sprintf("%s: %s %s %s %s",come1, day, time, r[:name],r[:title])
        DBlog::atte(db, come2 )
        reserve.updateStat( db,r[:id],stat: RsvConst::Normal, comment: "" )
      end
    end

    #
    # 重複 check
    #
    dupchk.each do |r|
      # title = Commlib::deleteOptStr( r[:title] )
      title = r[:title].sub(/【再】/,'').sub(/^\[[無新]\]/,'')
      row1 = reserve.selectSP( db, stat: RsvConst::NormalEnd, title: title )
      if row1.size > 0
        come1 = "重複の為無効化:"
        (day, time, w) = Commlib::stet_to_s( r[:start], r[:end] )
        come2 = sprintf("%s %s %s %s %s",come1, day, time, r[:name],r[:title])
        DBlog::atte(db, come2 )
        come1 = "重複"
        reserve.updateStat( db,r[:id],stat: RsvConst::NotUse, comment: come1 )
      end
    end
    
    Tuner.new.schedule2(db)

  end
    
  #
  #  予約の新規登録
  #
  def add( pid )
    subdir = @params["dir"] == nil ? nil : @params["dir"]
    jitan  = @params["jitan"] == nil ? 1 : 0

    programs = DBprograms.new
    reserve  = DBreserve.new
    DBaccess.new().open do |db|
      db.transaction do
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
  end

  #
  #  予約の削除
  #
  def del( rid )

    reserve  = DBreserve.new
    DBaccess.new().open do |db|
      db.transaction do
        reserve.delete( db, id: rid )
        self.check( db )
      end
    end
  end
  
  #
  #  予約内容の変更
  #  {"use"=>"on", "jitan"=>"on", "dir"=>"aaa" }
  def mod( rid )

    DBaccess.new().open do |db|
      db.transaction do
        use   = @params["use"] == "on" ? RsvConst::NotUse : RsvConst::Normal
        jitan = @params["jitan"] == "on" ? 0 : 1
        dir   = @params["dir"] 
        DBreserve.new.updateS( db, rid, use, jitan, dir )
        self.check( db )
      end
    end
  end


  #
  #  録画中を停止
  #
  def stop( rid )

    reserve  = DBreserve.new
    DBaccess.new().open do |db|
      db.transaction do
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
  
  
end

if File.basename($0) == "Reservation.rb"

  Reservation.new( ARGV[0].to_i )

end
