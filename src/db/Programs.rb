#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'yaml'


class DBprograms

  include Base
  
  def initialize( )
    @list = {
      id:         "id",
      chid:       "chid",
      evid:       "evid",
      title:      "title",
      detail:     "detail",
      extdetail:  "extdetail",
      start:      "start",
      end:        "end",
      duration:   "duration",
      categoryT1: "categoryT1",
      categoryT2: "categoryT2",
      categoryT3: "categoryT3",
      category:   "category",
      attachinfo: "attachinfo",
      video:      "video",
      audio:      "audio",
      freeCA:     "freeCA",
      wday:       "wday",
      updtime:    "updtime",
    }
    @para = []
    @list.each_pair { |k,v| @para << v }
    @tbl_name = "programs"
    @now = Time.now.to_i
  end

  def update( db, id, data )
    ( sql, args ) = makeUpdSql( @list, @tbl_name, data, id )
    db.execute( sql, *args )
  end
  
  def diff( old, new )
    dr = {}
    @list.each_pair do |k,v|
      next if k == :id or k == :updtime
      if new[k] != old[k]
        dr[k] ||= {}
        dr[k][:new] = new[k]
        dr[k][:old] = old[k]
      end
    end
    if dr.size > 0
      #diffDump( old, dr )
      return true
    else
      return false
    end
  end

  def  diffDump( data, dr )
    fname = LogDir + "/" + Time.now.strftime("epg_diff_%m%d.log")
    File.open( fname, "a") do |fp|
      fp.printf("%s %s %s %s\n",data[:chid],data[:evid],Time.at(data[:start]), data[:title])
      dr.each_pair do |k,v|
        fp.printf("--- %s ---\nold:%s\nnew:%s\n",k.to_s,v[:old],v[:new])
      end
      fp.print( "-" * 30 + "\n")
    end
  end

  
  def select( db, id: nil, evid: nil, chid: nil)
    ( sql, args ) = makeSelectSql( @para, @tbl_name, id: id, evid: evid,  chid: chid)
    row = db.execute( sql, args )
    row2 = row2hash( @list, row )
    row2.each do |tmp|
      tmp[:categoryA] = blob2array( tmp[:category] )
    end
    row2
  end

  def insert( db, data )
    ( sql, args ) = makeInsSql( @list, @para, @tbl_name, data )
    db.execute( sql, *args )
  end

  def bulkinsert2( db, data )
    if @bulksql == nil
      ( @bulksql, args ) = makeInsSql( @list, @para, @tbl_name, data[0] )
    end
    stmt = db.prepare( @bulksql )
    data.each do |d|
      args = []
      @list.each_pair do |k,v|
        args << d[ k ]
      end
      stmt.execute( args )
    end
    stmt.close
  end
  
  def bulkinsert( db, data )
    sql = "insert into #{@tbl_name} ( " + @para.join(",") + ") values "
    a1 = []
    data.each do |d|
      a2 = []
      @list.each_pair do |k,v|
        if d[ k ] == nil
          a2 << "NULL"
        elsif d[ k ].class == String
          a2 << "'" + d[ k ].gsub(/'/,"''") + "'"
        else
          a2 << d[ k ]
        end
      end
      a1 << "(" + a2.join(",") + ")"
    end
    sql += a1.join(",") + ";"
    db.execute( sql )
  end
  
  def delete( db, id )
    sql = "delete from #{@tbl_name} where id = ? ;"
    db.execute( sql, id )
  end

  def delete( db, id )
    sql = "delete from #{@tbl_name} where id = ? ;"
    if id.class != Array
      db.execute( sql, id )
    else
      stmt = db.prepare( sql )
      id.each do |id2|
        stmt.execute( id2 )
      end
      stmt.close
    end
  end
  
  def dataConv( db, d, chid, cateId )

    cateblob = cateId.flatten.pack("C*")
    cateText = []
    cateId.each do |v|
      next if v[0] == 0 or v[1] == 0
      cateText << sprintf("%d-%d",v[0],v[1])
    end

    tmp = d["extdetail"]
    extdetail = YAML.dump( tmp ) if tmp != nil and tmp != ""
    week = Time.at( d["start"] / 1000 ).wday
    r = {
      id:         nil,
      chid:       chid,
      title:      d["title"],
      detail:     d["detail"],
      extdetail:  extdetail,
      start:      d["start"] / 1000,
      end:        d["end"] / 1000,
      duration:   d["duration"],
      category:   SQLite3::Blob.new( cateblob ),
      categoryT1: cateText[0],
      categoryT2: cateText[1],
      categoryT3: cateText[2],
      attachinfo: d["attachinfo"].join("\n"),
      video:      "",
      audio:      "",
      freeCA:     d["freeCA"] == true ? 1 : 0,
      evid:       d["event_id"],
      wday:       week,
      updtime:    Time.now.to_i,
    }
    r
  end


  #
  #   カウント
  #
  def count( db )
    sql = "select count( id ) from programs "
    row = db.execute( sql )
    return row[0][0]
  end
  

  
  #
  #  ガーベージコレクション
  #
  def gc( db, chid )
    total = 0
    data = {}
    dels = []
    now = Time.now.to_i - ( 3600 * 24 )
    sql1 = "select id,evid,start,end,updtime from programs where chid = ? order by updtime desc ;"
    rows = db.execute( sql1, chid )
    rows.each do |row|

      # event_id が重なる古い方の削除
      evid = row[1]
      if data[ evid ] == nil
        data[ evid ] = true
      else
        dels << row[0]
        next
      end

      # 今より古いデータの削除
      if row[3] < now
        dels << row[0]
      end
    end
    
    # 削除
    delete( db, dels )
    total += dels.size

    # evid が変わり時間が重複した場合は、古い方を削除
    data = []
    dels = {}
    sql1 = "select id,evid,start,end,updtime from programs where chid = ? order by start  ;"
    rows = db.execute( sql1, chid )
    rows.each do |row|
      h = { :id => row[0],
            :evid => row[1],
            :st => row[2],
            :et => row[3] - 1,
            :updtime => row[4],
          }
      data << h
    end

    data.each do |tmp1|
      data.each do |tmp2|
        next if tmp1[:evid] == tmp2[:evid]
        next if ( tmp1[ :st ] - tmp2[ :st ]).abs > ( 3600 * 6 )
        next if dels[ tmp1[:id] ] != nil
        next if dels[ tmp2[:id] ] != nil
          
        if tmp1[:st].between?( tmp2[:st],tmp2[:et] ) or
          tmp1[:et].between?( tmp2[:st],tmp2[:et] )
          id = tmp1[:updtime] < tmp2[:updtime] ? tmp1[:id] : tmp2[:id]
          dels[ id ] = true
        end
      end
    end
    
    if dels.size > 0
      delete( db, dels.keys )
      total += dels.size
    end
    total
  end

  
  def dump(db, id )
    row = select(db, id: id )
    if row != nil
      tmp = row[0]
      printf("%8d %s %s %s %s %d\n",id, tmp[:chid],tmp[:evid],Time.at(tmp[:start]), tmp[:title],tmp[:updtime] )
    end
  end

  def selectSP( db,
                proid: nil,
                order: nil,
                chid: nil,
                evid: nil,
                tstart: nil,
                tend: nil,
                skip: nil
              )
    list = {
      chid:          "c.chid",
      svid:          "c.svid",
      band:          "c.band",
      name:          "c.name",
      skip:          "c.skip",
      pid:           "p.id",
      evid:          "p.evid",
      title:         "p.title",
      detail:        "p.detail",
      extdetail:     "p.extdetail",
      start:         "p.start",
      end:           "p.end",
      duration:      "p.duration",
      category:      "p.category",
      attachinfo:    "p.attachinfo",
      video:         "p.video",
      audio:         "p.audio",
      freeCA:        "p.freeCA",
      wday:          "p.wday",
      updtime:       "p.updtime",
    }
    para = []
    list.each_pair { |k,v| para << v }
    
    sql = "select " + para.join(",") + " from programs p inner join channel c on c.chid = p.chid "
    where = []
    args = []
    
    if proid != nil and proid.class == Array
      where << " p.id in ( " + proid.join(", ") + " )"
    elsif chid != nil and evid != nil 
      where << " p.chid = ? and p.evid = ? "
      args = [ chid, evid ]
    elsif tstart != nil and tend != nil 
      where <<  " p.end > ? and p.start < ? "
      args = [ tstart, tend ]
    elsif chid != nil and tend != nil 
      where << " p.end > ? and p.chid = ? "
      args = [ tend , chid ]
    elsif proid != nil 
      where <<  " p.id = ? "
      args << proid
    elsif tstart != nil
      where << " p.start > ? "
      args << tstart
    elsif chid != nil
      where <<  " p.chid = ? "
      args << chid
    end

    if skip != nil
      where <<  " c.skip = ? "
      args << skip
    end
    
    if where.size > 0
      sql += " where " + where.join( " and " )
    end

    if order != nil
      sql += order
    else
      sql += " order by p.start ;"
    end

    row = db.execute( sql, *args )
    row2 = row2hash( list, row )
    row2.each do |tmp|
      tmp[:categoryA] = blob2array( tmp[:category] )
    end
    row2
  end

  #
  # blob からArray に変換  [ [1m,1s],[2m,2s],[3m,3s] ]
  #
  def blob2array( str )
    a = str.unpack("C*")
    b = []
    3.times { b << [a.shift,a.shift] }
    b
  end
  
  
end
