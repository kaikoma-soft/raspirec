#!/usr/bin/ruby
# -*- coding: utf-8 -*-


class DBreserve

  include Base
  
  def initialize( )
    @list = {
      id:        "id",
      chid:      "chid",
      svid:      "svid",
      evid:      "evid",
      title:     "title",
      start:     "start",
      end:       "end",
      duration:  "duration",
      type:      "type",
      keyid:     "keyid",
      jitan:     "jitan",
      jitanExe:  "jitanExe",
      subdir:    "subdir",
      stat:      "stat",
      comment:   "comment",
      tunerNum:  "tunerNum",
      recpt1pid: "recpt1pid",
      category:  "category",
      dedupe:    "dedupe",
      fname:     "fname",
      ftp_stat:  "ftp_stat",
      dropNum:   "dropNum",
    }
    @para = []
    @list.each_pair { |k,v| @para << v }
    @tbl_name = "reserve"
  end

  
  #
  #   検索
  #
  def select( db, id: nil, evid: nil, chid: nil, tstart: nil, tend: nil, limit: nil, order: nil, keyid: nil, recpt1pid: nil, stat: nil )
    (sql, args ) = makeSelectSql( @para, @tbl_name,
                                  id: id, evid: evid, chid: chid,
                                  tstart: tstart, tend: tend,
                                  limit: limit,
                                  order: order,
                                  keyid: keyid,
                                  recpt1pid: recpt1pid,
                                  stat:      stat,
                                )
    row = db.execute( sql, *args )
    row2hash( @list, row )
  end

  #
  #   カウント
  #
  def count( db, tstart: nil, titleL: nil  )
    sql = "select count( id ) from reserve"
    argv = []
    where = []
    if tstart != nil
      where << "start < ?"
      argv << tstart
    end
    if titleL !=  nil 
      where << "title like ?"
      argv << titleL
    end
    if where.size > 0
      sql += " where " + where.join(" and ")
    end
       
    row = db.execute( sql, *argv )
    return row[0][0]
  end

  #
  #   検索 ( reserve inner join channel )
  #
  def selectSP( db, id: nil, order: nil, stat: nil, tstart: nil, tend: nil, title: nil, titleL: nil, limit: nil )
    chan = %w( name band )
    argv = []
    sql = "select " + @para.map{|v| "r." + v }.join(",") + "," +
          chan.map{|v| "c." + v }.join(",") +
          " from reserve r inner join channel c on c.chid = r.chid ";
    where = []
    if stat != nil
      if stat.class == Array
        where << "(" + Array.new( stat.size, "r.stat = ? " ).join(" or ") + ")"
        argv += stat
      else
        where << " stat = ? "
        argv << stat
      end
    end
    if tstart !=  nil and tend != nil
      where << " ? < r.end and r.start < ?"
      argv += [ tstart, tend ]
    elsif tstart !=  nil 
      where << " r.start < ?"
      argv << tstart
    elsif tend !=  nil 
      where << " r.end > ?"
      argv << tend
    elsif title !=  nil 
      where << " r.title = ?"
      argv << title
    elsif id !=  nil 
      where << " r.id = ?"
      argv << id
    end

    if titleL !=  nil 
      where << " r.title like ?"
      argv << titleL
    end
    
    if where.size > 0
      sql += " where " + where.join(" and ")
    end

    if order == nil
      sql += " order by r.start "
    else
      sql += order
    end

    if limit != nil
      sql += " " + limit
    end

    row = db.execute( sql, *argv )
    list = @list.dup
    chan.each { |v| list[ v.to_sym ] = v }

    row2hash( list, row )
  end

  #
  #   検索(ファイル転送リスト)
  #
  def getTSFT( db )
    sql = "select id, subdir, fname from reserve where stat = ? and ftp_stat = ? ;"
    args = [ RsvConst::NormalEnd, RsvConst::Off ]
    row = db.execute( sql, *args )
    list = {
      id:       "id",
      subdir:   "subdir",
      fname:    "fname",
    }
    row2hash( list, row )
  end

  #
  #   packetChkが未のもの
  #
  def getPacketChk( db )
    sql = "select id, subdir, fname from reserve where stat = ? and dropNum is NULL ;"
    args = [ RsvConst::NormalEnd]
    row = db.execute( sql, *args )
    list = {
      id:       "id",
      subdir:   "subdir",
      fname:    "fname",
    }
    row2hash( list, row )
  end
  
  #
  #   登録
  #
  def insert( db, data )
    (sql, args ) = makeInsSql( @list, @para,@tbl_name, data )
    row = db.execute( sql, *args )
  end

  #
  #   削除
  #
  def delete( db, id: nil, keyid: nil, stat: nil, start: nil  )
    args = []
    sql = "delete from reserve "
    tmp = []
    item = %w( id keyid stat )
    item.each do |name|
      tmp2 = eval("#{name}")
      if tmp2 != nil
        tmp << " #{name} = ? "
        args << tmp2
      end
    end
    if start != nil
      tmp << " start > ? "
      args << start
    end
      
    sql += " where "
    sql += tmp.join(" and ")

    db.execute( sql, *args )
  end

  #
  #   変更
  #
  def update( db, rid, jitan, dir )
    sql = "update reserve set jitan = ?, subdir = ? where id = ? ;"
    db.execute( sql, jitan, dir, rid )
  end

  #
  #   変更(ステータス等)
  #
  def updateS( db, rid, stat, jitan, dir )
    sql = "update reserve set stat = ?, jitan = ?, subdir = ? where id = ? ;"
    db.execute( sql, stat, jitan, dir, rid )
  end

  #
  #   変更(チュナー関係)
  #
  def updateJ( db, jitanExe, tunerNum, stat, come, rid )
    sql = "update reserve set jitanExe = ?, tunerNum = ?, stat = ?, comment = ? where id = ? ;"
    db.execute( sql, jitanExe, tunerNum, stat, come, rid )
  end

  #
  #   変更(時間関係)
  #
  def updateT( db, tstart, tend, duration, id )
    sql = "update reserve set start = ?, end = ?, duration = ? where id = ? ;"
    db.execute( sql, tstart, tend, duration, id )
  end

  #
  #   変更(その他)
  #
  def updateA( db, id, title: nil )
    sql = "update reserve set "
    para = []
    args = []
    if title != nil
      para << " title = ? "
      args << title
    end

    if para.size > 0
      sql += para.join("," ) + "where id = ? ;"
      args << id
      db.execute( sql, args )
    end
  end

  #
  #   変更
  #
  def updateStat( db, id,
                  stat: nil,
                  comment: nil,
                  tunerNum: nil,
                  jitanExe: nil,
                  recpt1pid: nil,
                  ftp_stat: nil,
                  fname:    nil,
                  dropNum:  nil
                )
    args = []
    sql = "update reserve set "
    tmp = []
    item = %w( stat comment tunerNum jitanExe recpt1pid ftp_stat fname dropNum )
    item.each do |name|
      tmp2 = eval("#{name}")
      if tmp2 != nil
        tmp << " #{name} = ? "
        args << tmp2
      end
    end
    
    sql += tmp.join(",")
    sql += " where id = ? ;"
    args << id

    db.execute( sql, *args )
  end

  def sdfsdfsdf()
    if stat != nil
      tmp << " stat = ? "
      args << stat
    end
    if comment != nil
      tmp <<  " comment = ? " 
      args << comment
    end
    if tunerNum != nil
      tmp << " tunerNum = ? " 
      args << tunerNum
    end
    if jitanExe != nil
      tmp << " jitanExe = ? " 
      args << jitanExe
    end
    if recpt1pid != nil
      tmp << " recpt1pid = ? " 
      args << recpt1pid
    end
    if ftp_stat != nil
      tmp << " ftp_stat = ? " 
      args << ftp_stat
    end
    if fname != nil
      tmp << " fname = ? " 
      args << fname
    end
  end

  #
  #  削除
  #
  def deleteOld( db, time )
    sql = "delete from reserve where start < ? ;"
    db.execute( sql, time )
  end

  #
  #  dropNum の格納値の合成    xxxxx 00 y z     null = 未
  #
  def makeDropNum( drer,        # drop + error (xxxxx)
                   pcr,         # PCR          ( y )
                   execerror    # 実行失敗     ( z )
                 )
    return (( drer << 4 ) + ( (pcr & 0x01 ) << 1 ) + (execerror & 0x01) )
  end

  #
  #  dropNum の格納値の分解
  #
  def parseDropNum( val )
    drer      = val >> 4
    pcr       = ( val >> 1 ) & 0x01
    execerror = val & 0x01
    return [ drer, pcr, execerror ]
  end

  #
  #  title hash を設定
  #
  def titleHash( db )
    sql = "select id,title,tunerNum from reserve where stat = ? and tunerNum < ? "
    row = db.execute( sql, RsvConst::NormalEnd, 0xffff )
    row.each do |tmp|
      ( id, title, tunerNum ) = tmp
      titleH = Commlib::makeHashKey( title )
      tunerNum2 = ( RsvConst::HashSetFlag << 16 ) + ( tunerNum & 0xffff )
      sql = "update reserve set tunerNum = ?, recpt1pid = ? where id = ? ;"
      db.execute( sql, tunerNum2, titleH, id )
      #pp "#{id} #{title} #{titleH} #{tunerNum2}" if $debug == true
    end
    
  end

  #
  #  予約テーブルの title と programs のtitle を比較する。
  #
  def titleChk( db )
    sql = "select r.id, r.title, p.title from reserve r inner join programs p on p.chid = r.chid and p.evid = r.evid and r.title != p.title and r.end > ? ; "

    row = db.execute( sql, Time.now.to_i - 3600 )
    if row != nil and row.size > 0
      row.each do |r|
        str = sprintf("Error: titleChk() %8d : %s : %s",r[0],r[1],r[2] )
        DBlog::sto(str)
      end
    end
  end

  #
  #   二重録画の検出
  #
  def dupRecChk( db )
    sql = "select title from reserve where stat = 2 GROUP BY title,evid,chid  HAVING COUNT(title) > 1"
    row = db.execute( sql)
    if row != nil and row.size > 0
      row.each do |r|
        str = sprintf("Error: dupRecChk() %s",r[0] )
        DBlog::sto(str)
      end
    end
    
  end
  
  
end
