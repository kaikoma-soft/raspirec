#!/usr/bin/ruby
# -*- coding: utf-8 -*-


class DBchannel

  include Base

  def initialize( )
    @list = {
      id:                  "id",
      band:                "band",
      band_sort:           "band_sort",
      chid:                "chid",
      tsid:                "tsid",
      onid:                "onid",
      svid:                "svid",
      name:                "name",
      stinfo_tp:           "stinfo_tp",
      stinfo_slot:         "stinfo_slot",
      updatetime:          "updatetime",
      skip:                "skip",
    }
    @para = []
    @list.each_pair { |k,v| @para << v }
    @tbl_name = "channel"
  end

  #
  #  chanle情報の取得
  #
  def select( db, id: nil, chid: nil, order: nil, updatetime: nil )
    ( sql,args ) = makeSelectSql( @para, @tbl_name, id: id, chid: chid, order: order, updatetime: updatetime )
    row = db.execute( sql, *args )
    row2hash( @list, row )
  end

  #
  #  追加
  #
  def insert( db, data )
    ( sql, args ) = makeInsSql( @list, @para, @tbl_name, data )
    db.execute( sql, *args )
    nameChk( db )
  end

  #
  #  削除
  #
  def delete( db, chid )
    sql = "delete from #{@tbl_name} where chid = ? "
    db.execute( sql, chid )
  end

  #
  #  更新
  #
  def update( db, chid, key, val )
    sql = "update #{@tbl_name} set #{key.to_s} = ? where chid = ? "
    db.execute( sql, val, chid )
  end
  
  #
  #  skip の更新
  #
  def updateSkip( db, skip, chid )
    sql = "update #{@tbl_name} set skip = ? where chid = ? "
    db.execute( sql, skip, chid )
  end

  #
  #  更新時間に -1 をセットして無効に
  #
  def invalid( db, chid )
    sql = "update #{@tbl_name} set updatetime = -1 where chid = ? "
    db.execute( sql, chid )
  end

  #
  #  更新時間の取得
  #
  def getUpdateTime( db, phch )
    sql = "select distinct phch,updatetime from #{@tbl_name} "
    if phch != nil and phch.class == Array
      sql += " where phch in ( " + phch.map{|v| %Q("#{v}")}.join(", ") + " )"
    else
      sql += " where phch = #{phch} "
    end
    db.execute( sql )
  end

  #
  #  放送局名に重複がある場合は、svid を付加する。
  #
  def nameChk( db )
    sql = "select id, name, svid from #{@tbl_name} order by svid"
    row = db.execute( sql)
    list = {}
    row.each do |r|
      ( id, name, svid ) = r
      if list[ name ] == true
        newname = "#{name}(#{svid})"
        sql = "update #{@tbl_name} set name = ? where id = ? "
        db.execute( sql, newname, id )
      end
      list[ name ] = true
    end
  end

  #
  #  data に差異があるか
  #
  def dataDiff( old, new )
    ret = []
    keys = [ :tsid, :onid, :svid, :name, :stinfo_tp, :stinfo_slot ]
    keys.each do |key|
      old2 = key == :name ? old[ key ].sub(/\(\d+\)$/,'') : old[ key ]
      if old2 != new[ key ]
        ret << key
      end
    end
    return ret
  end
  
  #
  #  JSON のデータから DB 向けに変換
  #
  def dataConv( json, phch, patch = nil )
    band = ""
    bsort = 0
    case json["id"]
    when /^BS/ then band = Const::BS ; bsort = 2
    when /^CS/ then band = Const::CS ; bsort = 3
    when /^GR/ then band = Const::GR ; bsort = 1 
    end
    h = { id:          nil,
          band:        band,
          band_sort:   bsort,
          chid:        json["id"],
          tsid:        json["transport_stream_id"],
          onid:        json["original_network_id"],
          svid:        json["service_id"],
          name:        json["name"],
          stinfo_tp:   nil,
          stinfo_slot: nil,
          updatetime:  0,
          skip:        0,
        }

    # 本放送以外はスキップ flag を立てる
    if band == Const::BS or band == Const::CS
      svid = h[:svid].to_i
      if ( band == Const::BS and svid > 699 ) or ( svid == 101 and band == Const::CS )
        # DBlog::sto( "set skip ch #{h["name"]} #{svid}") if $debug == true
        h[:skip] = 1
      end
    end

    if band == Const::GR
      h[:stinfo_tp]   = phch
      h[:stinfo_slot] = "0"
    else
      if json["satelliteinfo"] != nil and json["satelliteinfo"]["TP"] != nil
        h[:stinfo_tp] =  json["satelliteinfo"]["TP"]
      end
      if json["satelliteinfo"] != nil and json["satelliteinfo"]["SLOT"] != nil
        h[:stinfo_slot] =  json["satelliteinfo"]["SLOT"].to_s
      end
    end

    # パッチ当て
    if patch != nil
      chid = h[:chid]
      if patch[ chid ] != nil
        patch[ chid ].each_pair do |k,v|
          if h[ k ] != nil
            #pp "#{h[ k ]} -> #{v}"
            h[ k ] = v
          end
        end
      end
    end
    
    h
  end

  #
  # chid 対 phch の対応表(hash) を返す
  #
  def makeChid2Phch(db)
    chid2phch = {}          
    row = self.select( db )
    row.each do |r|
      chid = r[:chid]
      phch = Commlib::makePhCh( r )
      chid2phch[ chid ] = phch
    end
    return chid2phch
  end
end
