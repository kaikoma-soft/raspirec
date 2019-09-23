#!/usr/bin/ruby
# -*- coding: utf-8 -*-


class DBcategory

  include Base
  
  def initialize( )
    @listL = {
      id:    "id",
      name:  "name",
    }
    @listM = {
      id:    "id",
      pid:   "pid",
      name:  "name",
    }
    @paraL = []
    @listL.each_pair { |k,v| @paraL << v }
    @paraM = []
    @listM.each_pair { |k,v| @paraM << v }
    @changed = true
    @tbl_nameL = "categoryL"
    @tbl_nameM = "categoryM"
  end

  
  #
  #  id から文字列に変換
  #
  def conv2str(db, l = nil, m = nil )
    rl = rm = ""
    if l != nil and l != 0
      rl = selectL(db, id: l).first[:name]
    end
    if m != nil and m != 0
      rm = selectM(db, id: m).first[:name]
    end

    [ rl, rm ]
  end


  #
  #  json文字列から id に変換
  #
  def conv2id(db, data )
    r = []
    data.each_with_index do |cate,n|
      l = cate["large"]["ja_JP"]
      m = cate["middle"]["ja_JP"]
      tryc = lid = mid = 0
      begin
        raise if (lid = selectC(db, l: l )) == nil
      rescue
        insertL(db, l )
        if tryc == 0
          tryc += 1
          retry
        else
          raise
        end
      end
      tryc = 0
      begin
        raise if (mid = selectC(db, l: lid, m: m )) == nil
      rescue
        insertM(db, lid, m )
        if tryc == 0
          tryc += 1
          retry
        else
          raise
        end
      end
      r << [ lid,mid ]
    end
    r.sort!
    ( 3 - r.size).times {|n| r << [0,0] }
    r
  end

  #
  #  キャッシュ作成
  #
  def createCache( db )
    @main = {}
    @sub  = {}
    sql = "select * from categoryL ;"
    row = db.execute( sql )
    if row != nil and row.size != 0 
      row.each do |tmp|
        @main[ tmp[1] ] = tmp[0]
      end
    end

    sql = "select * from categoryM ;"
    row = db.execute( sql )
    if row != nil and row.size != 0 
      row.each do |tmp|
        @sub[ tmp[1] ] ||= {}
        @sub[ tmp[1] ][ tmp[2] ] = tmp[0]
      end
    end
    @changed = false

  end

  def selectL(db, id: nil, name: nil)
    ( sql, args ) = makeSelectSql( @paraL, @tbl_nameL, id: id, name: name)
    row = db.execute( sql, args )
    row2hash( @listL, row )
  end

  def selectM(db, id: nil, pid: nil, name: nil)
    ( sql, args ) = makeSelectSql( @paraM, @tbl_nameM, id: id, pid: pid,name: name)
    row = db.execute( sql, args )
    row2hash( @listM, row )
  end

  def selectC(db, l: nil, m: nil)
    createCache( db ) if @changed == true
    if l != nil and m != nil
      if @sub[ l ] != nil
        return @sub[ l ][ m ]
      end
    elsif l != nil
      return @main[ l ]
    end
    nil
  end
    
  def insertL(db, cate )
    sql = "insert into categoryL values (null, ? );"
    db.execute( sql, cate )
    @changed = true
  end

  def insertM(db, pid, cate )
    sql = "insert into categoryM values (null, ?, ? );"
    db.execute( sql, pid, cate, )
    @changed = true
  end
  
  
end
