#!/usr/bin/ruby
# -*- coding: utf-8 -*-


class DBfilter

  include Base
  
  def initialize( )
    @list = {
      id:        "id",
      type:      "type",
      title:     "title",
      key:       "key",
      exclude:   "exclude",
      regex:     "regex",
      band:      "band",
      target:    "target",
      chanel:    "chanel",
      category:  "category",
      wday:      "wday",
      result:    "result",
      jitan:     "jitan",
      subdir:    "subdir",
      freeonly:  "freeonly",
      dedupe:    "dedupe",
    }
    @para = []
    @list.each_pair { |k,v| @para << v }
    @tbl_name = "filter"
  end

  #
  #
  #
  def delete( db, id )
    sql = "delete from filter where id = ? ;"
    db.execute( sql, id )
  end

  
  #
  #  条件検索の取得
  #
  def select( db, id: nil, type: nil )
    ( sql, args ) = makeSelectSql( @para, @tbl_name, id: id, type: type)
    row = db.execute( sql, args )
    row2hash( @list, row )
  end
  
  #
  #  条件検索の追加
  #
  def insert( db, data )

    ( sql, args ) = makeInsSql( @list, @para, @tbl_name, data )
    db.execute( sql, *args )
  end

  #
  #  条件検索の書き換え
  #
  def update( db, data, id )

    ( sql, args ) = makeUpdSql( @list, @tbl_name, data, id )
    db.execute( sql, *args )
  end

  #
  #  検索結果の更新
  #
  def update_res(db, id, size )
    sql = "update filter set result = ? where id = ?;"
    r = db.execute( sql, size, id )
  end
  
end
