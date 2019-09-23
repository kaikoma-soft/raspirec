#!/usr/bin/ruby
# -*- coding: utf-8 -*-


class DBfilterResult

  include Base
  
  def initialize( )
    @list = {
      id:      "id",
      pid:     "pid",
      rid:     "rid",
    }
    @para = []
    @list.each_pair { |k,v| @para << v }
    @tbl_name = "filter_result"
  end

  #
  #   格納
  #
  def insert(db, pid, rid )
    data = { id: nil, pid: pid, rid: rid }
    ( sql, args ) = makeInsSql( @list, @para, @tbl_name, data )
    #pp sql,args
    db.execute( sql, *args )
  end


  #
  #   検索
  #
  def select(db, pid: nil, tend: nil )
    ( sql, args ) = makeSelectSql( @para,@tbl_name, pid: pid, tend: tend )
    #pp sql,args
    row = db.execute( sql, *args )
    row2hash( @list, row )
  end


  #
  #  削除
  #
  def delete( db, id )
    sql = "delete from filter_result where pid = ? ;"
    db.execute( sql, id )
  end

  #
  #  更新
  #
  def update( db, data, id )
    ( sql, args ) = makeUpdSql( @list, @tbl_name, data, id )
    #pp sql,args
    db.execute( sql, *args )
  end
  
end
