#!/usr/bin/ruby
# -*- coding: utf-8 -*-


module Base
  
  #
  #  select文の生成
  #
  def makeSelectSql(para, tname,
                    id: nil,
                    pid: nil,
                    type: nil,
                    svid: nil,
                    evid: nil,
                    chid: nil,
                    order: nil,
                    name:  nil,
                    tstart: nil,
                    tend: nil,
                    limit: nil,
                    keyid: nil,
                    updatetime: nil,
                    skip:   nil,
                    stat:   nil,
                    recpt1pid: nil
                   )
    where = []
    args = []
    sql = "select " + para.join(",") + " from #{tname} "
    if id != nil
      where << " id = ? "
      args << id
    elsif pid != nil
      where << " pid = ? "
      args << pid
    elsif type != nil
      where << " type = ? "
      args << type
    elsif name != nil
      where << " name = ? "
      args << name
    elsif chid != nil and evid != nil
      where << " chid = ? and evid = ? "
      args += [ chid, evid ]
    elsif chid != nil
      where << " chid = ? "
      args << chid
    elsif keyid != nil
      where << " keyid = ? "
      args << keyid
    elsif updatetime != nil 
      where << " updatetime < ?  "
      args << updatetime
    elsif evid != nil
      where << " evid = ? "
      args << evid
    # else # デバック用
    #   if tstart == nil and tend == nil and stat == nil
    #     DBlog::sto( "Error: makeSelectSql()" )
    #     if $debug == true
    #       DBlog::sto( caller(0)[0..9].join("\n" ))
    #     end
    #   end
    end

    # ## デバック用
    # found = []
    # %W( id pid type name chid keyid updatetime evid tstart tend ).each do |n|
    #   r = if eval( "defined? #{n}" )
    #         eval( n )
    #       else
    #         nil
    #       end
    #   found << n if r != nil
    # end
    # if found.size > 1
    #   tmp = found.join(",") 
    #   if tmp != "chid,evid" and
    #     tmp != "chid,evid,tstart" and
    #     tmp != "id,type" and
    #     tmp = sprintf("@@@: makeSelectSql %d %s\n%s\n",found.size, found.join(","),caller(0).join("\n"))
    #     DBlog::sto( tmp )
    #   end
    # end
                                                               
    if tstart != nil and tend != nil
      where << " ( ? < end and start < ? ) " # 番組表の top と Bottom
      args += [ tstart, tend ]
    elsif tstart == nil and tend != nil
      where << " ? < end "
      args << tend
    elsif tstart != nil and tend == nil
      where << " ? < start "
      args << tstart
    end

    
    if stat != nil
      if stat.class == Array
        where << " (" + Array.new( stat.size, "stat = ? " ).join(" or ") + ") "
        args += stat
      else
        where << " stat = ?  "
        args << stat
      end
    end

    if recpt1pid != nil 
      where << " recpt1pid = ?  "
      args << recpt1pid
    end
    
    if skip != nil 
      where << " skip = ? "
      args << skip
    end
    
    if where.size > 0
      sql += " where " + where.join(" and ")
    end
    
    if order == nil
      sql += " order by id "
    else
      sql += order
    end
    if limit != nil 
      sql += " limit ? "
      args << limit
    end
    sql += ";"
    
    [ sql, args ]
  end

  #
  #  insert文の生成
  #
  def makeInsSql( list, para, tname, data )
    args = []
    list.each_pair do |k,v|
      args << data[ k ]
    end
    sql = "insert into #{tname} ( " + para.join(",") + ") values ("
    sql += (Array[ "?"] * para.size).join(",")
    sql += " )"
    [ sql, args ]
  end

  #
  #  update 文の生成
  #
  def makeUpdSql( list, tname, data, id )
    args = []
    para = []
    list.each_pair do |k,v|
      next if k == :id
      args << data[ k ]
      para << "#{v} = ?"
    end
    sql = "update #{tname} set " + para.join(",")
    sql += " where id = #{id} "
    [ sql, args ]
  end

  def row2hash( list, row )
    r = []
    if row != nil
      row.each do |tmp|
        h = {}
        list.each_key { |k| h[k] = tmp.shift }
        r << h
      end
    end
    r
  end

  #
  #  最後に insert した rowid を返す。
  #
  def last_insert_rowid(db)
    sql = "select last_insert_rowid();"
    r = db.execute( sql )
    r[0][0]
  end

end
