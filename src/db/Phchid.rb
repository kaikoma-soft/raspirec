#!/usr/bin/ruby
# -*- coding: utf-8 -*-


class DBphchid

  include Base
  
  def initialize( )
    @list = {
      id:          "id",
      phch:        "phch",
      chid:        "chid",
      updatetime:  "updatetime",
    }
    @para = []
    @list.each_pair { |k,v| @para << v }
    @tbl_name = "phchid"
  end

  #
  #   検索
  #
  def select( db, phch: nil, chid: nil, updatetime: nil )
    sql = "select id,phch,chid,updatetime from #{@tbl_name} "
    where = []
    args  = []
    if phch != nil
      where << " phch = ? "
      args << phch
    end
    if chid != nil
      where << " chid = ? "
      args << chid
    end
    if updatetime != nil
      where << " updatetime < ? "
      args << updatetime
    end
    
    if where.size > 0
      sql += " where " + where.join(" and ")
    end

    row = db.execute( sql, args )
    row2hash( @list, row )
  end

  #
  #  追加
  #
  def add(db, phch, chid,  updatetime )
    sql = "select id from #{@tbl_name} where phch = ? and chid = ? "
    row = db.execute( sql, phch, chid )
    if row.size == 0
      sql = "insert into #{@tbl_name} ( phch, chid, updatetime) values (?,?,?)"
      db.execute( sql, phch, chid, updatetime )
    else
      sql = "update #{@tbl_name} set updatetime = ? where phch = ? "
      db.execute( sql, updatetime, phch )
    end
  end

  #
  #  touch
  #
  def touch(db, updatetime, phch: nil, chid: nil  )
    sql = "update #{@tbl_name} set updatetime = ? "
    where = []
    args  = [ updatetime ]
    if phch != nil
      where << " phch = ? "
      args << phch
    end
    if chid != nil
      where << " chid = ? "
      args << chid
    end
    if where.size > 0
      sql += " where " + where.join(" and ")
    end

    db.execute( sql,args )
  end

  #
  #  削除
  #
  def delete(db, phch )
    sql = "delete from #{@tbl_name} where phch = ? "
    db.execute( sql, phch )
  end

end
