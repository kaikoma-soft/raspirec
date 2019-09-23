#!/usr/bin/ruby
# -*- coding: utf-8 -*-


class DBkeyval

  include Base
  
  def initialize( )
    @list = {
      key:     "key",
      val:     "val",
    }
    @para = []
    @list.each_pair { |k,v| @para << v }
    @tbl_name = "keyval"
  end

  #
  #   格納
  #
  def insert(db, key, val )
    data = { key: key, val: val }
    ( sql, args ) = makeInsSql( @list, @para, @tbl_name, data )
    db.execute( sql, *args )
  end


  #
  #   検索
  #
  def select( db, key )
    sql = "select val from #{@tbl_name} where key = ? ;"
    row = db.execute( sql, key)
    if row != nil and row[0] != nil
      return  row[0][0]
    end
    nil
  end


  #
  #  削除
  #
  def delete( db, key )
    sql = "delete from #{@tbl_name} where key = ? ;"
    db.execute( sql, key )
  end

  #
  #  更新
  #
  def upsert( db, key, val )
    sql = "INSERT OR REPLACE INTO #{@tbl_name} (key, val) VALUES (?,?) ;"
    db.execute( sql, key, val )
  end
  
end
