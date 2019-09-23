#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  フィルター関係
#

class FilterM

  def initialize( params = nil )
    @params = params if params != nil
  end

  #
  #  form のパラメータ解析
  #
  def formAna( params, type = :filter )
    d = {}
    d[:id]      = params[ "id" ] == nil ? nil : params[ "id" ].to_i
    d[:type]    = type == :filter ? 0 : 1
    d[:title]   = params[ "title1" ]
    d[:key]     = params[ "key" ] == nil ? nil : params[ "key" ].gsub(/　/,' ')
    d[:exclude] = params[ "exclude" ]
    d[:regex]   = params[ "stype" ] == "regex" ? 1 : 0
    d[:band]    = 0
    [ "band_gr","band_bs","band_cs" ].each_with_index do |b,n|
      d[:band] += 2 ** n if params[ b ] == "on"
    end
    d[:target] = params[ "target" ] == "T" ? 0 : 1
    d[:chanel] = params[ "ch" ].join(" ") if params[ "ch" ] != nil
    d[:category] = "0"
    d[:category] = params[ "cate" ].join(" ") if params[ "cate" ] != nil
    d[:wday] = 0
    0.upto(6) do |n|
      if params[ "wday#{n}"] == "on"
        d[:wday] += 2 ** n
      end
    end
    d[:result] = 0
    d[:jitan] = params["jitan"] == "on" ? RsvConst::JitanOn : RsvConst::JitanOff
    d[:subdir] = params["dir"]
    d[:freeonly] = params["freeonly"] == "on" ? RsvConst::FO : RsvConst::Off
    d[:dedupe] = params["dedupe"] == "on" ? RsvConst::Dedupe : RsvConst::Off
    d
  end
  
  #
  #  新規登録/変更
  #
  def add( params, type )

    d = formAna( params, type )
    id = d[:id]
    filter = DBfilter.new
    filterR = DBfilterResult.new
    reserve = DBreserve.new
    DBaccess.new().open do |db|
      db.transaction do
        if id == nil            # 新規
          filter.insert( db, d )
          id = filterR.last_insert_rowid(db)
        else                    # 変更
          filter.update( db, d, id )
        end
        filterR.delete( db, id )
        reserve.delete( db, keyid: id, start: Time.now.to_i )
      end
    end
    r = search_new( id )
    if type == :autoRsv # 自動予約
      DBaccess.new().open do |db|
        db.transaction do
          rsv_update( db, id: id )
          Reservation.new.check( db )
        end
      end
    end
    
    return id
  end

  #
  #  削除
  #
  def del( id )
    if $debug == true
      DBlog::sto("Fileter.del(#{id})" )
    end
    filter = DBfilter.new
    filterR = DBfilterResult.new
    DBaccess.new().open do |db|
      db.transaction do
        reserve = DBreserve.new
        reserve.delete( db, keyid: id, start: Time.now.to_i )
        filter.delete( db, id )
        filterR.delete( db, id )
      end
    end
  end
  
  def keika( n, t )
    printf("p%d %.2f\n",n, Time.now - t )
  end

  #
  #  検索の実行
  #  
  def search( db, id: nil, fd2: nil  )

    filter = DBfilter.new
    filterR = DBfilterResult.new
    prog = DBprograms.new
    pd = prog.selectSP( db, tstart: Time.new.to_i )
    # filterR.delete( db, id )
    if fd2 == nil 
      fd = filter.select( db, id: id )
      fd.each do |fd2|
        filterR.delete( db, fd2[:id] )
        r = search2( pd, fd2 )
        r.each do |rid|
          filterR.insert(db, fd2[:id], rid )
        end
        filter.update_res(db, fd2[:id],r.size )
      end
    else
      r = search2( pd, fd2 )
    end
    r
  end

  #
  #  検索の実行
  #  
  def search_new( id  )

    filter  = DBfilter.new
    filterR = DBfilterResult.new
    fd = nil
    DBaccess.new().open do |db|
      db.transaction do
        fd = filter.select( db, id: id )
        filterR.delete( db, fd[0][:id] )
        fd2 = fd[0]
        r = search3( db, fd2 )
        r.each do |rid|
          filterR.insert(db, fd2[:id], rid )
        end
        filter.update_res(db, fd2[:id],r.size )
      end
    end

  end

  
  #
  #  検索の全実行: 時間が掛かるので、逆に transaction の粒度を下げる。
  #  
  def searchAll( sleep = true )

    prog = DBprograms.new
    filter = DBfilter.new
    filterR = DBfilterResult.new

    pd = fd = nil
    DBaccess.new().open do |db|
      fd = filter.select( db, id: nil )
    end

    fd.each do |fd2|
      DBaccess.new().open do |db|
        db.transaction do
          r = search3( db, fd2 )
          filterR.delete( db, fd2[:id] )
          r.each do |rid|
            filterR.insert(db, fd2[:id], rid )
          end
          filter.update_res(db, fd2[:id],r.size )
        end
      end
      sleep( 1 ) if sleep == true
    end

  end
  
  #
  #  検索の実行 その２
  #  
  def search2( pd, fd )

    startT = Time.now
    r = []
    key  = nil
    excl = nil
    fd[:key].strip! if fd[:key] != nil
    fd[:exclude].strip! if fd[:exclude] != nil
    if fd[:regex] == 0      # 単純文字列検索
      if fd[:key] != nil and fd[:key] != ""
        key = "^"
        fd[:key].split.each do |str|
          key += sprintf("(?=.*%s)",Regexp.escape(str) )
        end
      end
      if fd[:exclude] != nil and fd[:exclude] != ""
        excl = sprintf("(%s)",fd[:exclude].split.map{|v| Regexp.escape(v)}.join("|"))
      end
    else
      key = fd[:key] if fd[:key] != nil and fd[:key] != ""
      excl = fd[:exclude] if fd[:exclude] != nil and fd[:exclude] != ""
    end

    #reg = "^(?=.*ニュース)(?=.*天気)"
    key2 = Regexp.new(key) if key != nil
    excl2 = Regexp.new(excl) if excl != nil

    band = {}
    band["GR"] = true if fd[:band][0] != 0
    band["BS"] = true if fd[:band][1] != 0
    band["CS"] = true if fd[:band][2] != 0
    wday = {}
    0.upto(6) do |n|
      wday[n] = true if fd[:wday][n] != 0
    end

    chanel = {}
    if fd[:chanel] != nil
      fd[:chanel].split.each do |ch|
        if ch == "0"
          chanel = nil
          break
        end
        chanel[ ch ] = true
      end
    end

    cate = []
    if fd[:category] == nil or fd[:category] == "0" 
      cate = nil
    else
      fd[:category].split.each_with_index do |tmp,n|
        if tmp == "0"
          cate = nil
          break
        elsif tmp =~ /(\d+)-(\d+)/
          cate[n] = {}
          cate[n][ :l ] = $1.to_i
          cate[n][ :m ] = $2.to_i
        end
      end
    end

    count = 0
    pd.each do |pd2|
      next if band[ pd2[:band] ] != true
      next if wday[ pd2[:wday] ] != true
      next if chanel != nil and chanel[ pd2[:chid] ] != true
      next if fd[:freeonly] == RsvConst::FO and pd2[:freeCA] == 1
      break if count >= FilConst::SeachMax

      if cate != nil
        tmp = pd2[:categoryA]
        foundF = false
        cate.each do |c|
          if c[ :m ] == 0
            tmp.each do |tmp2|
              if tmp2[0] == c[:l] 
                foundF = true
                next
              end
            end
            next if foundF == true
          else
            tmp.each do |tmp2|
              if tmp2[0] == c[:l] and tmp2[1] == c[:m] 
                foundF = true
                next
              end
            end
            next if foundF == true
          end
        end
        next if foundF == false
      end
        
      st = pd2[:title]
      if fd[:target ] > 0
        if pd2[:textall] == nil
          pd2[:textall] = pd2[:title]
          pd2[:textall] += pd2[:detail] if pd2[:detail] != nil
          pd2[:textall] += pd2[:extdetail] if pd2[:extdetail] != nil
          pd2[:textall].gsub!(/\n/,'')
        end
        st = pd2[:textall]
      end
      
      if key != nil
        if st =~ key2
          if excl == nil or !(st =~ excl2 )
            r << pd2[:pid]
            count += 1
          end
        end
      else
        if excl == nil or !(st =~ excl2 )
          r << pd2[:pid]
          count += 1
        end
      end
    end
    if $debug == true
      tmp = sprintf("search2() result = %3d time=%.2f",r.size,Time.now - startT)
      DBlog::sto( tmp )
    end
    r
  end

  #
  #   自動予約による予約の投入
  #
  def rsv_update( db, id: nil )
    filter = DBfilter.new
    filterResult = DBfilterResult.new
    programs = DBprograms.new
    reserve = DBreserve.new

    now = Time.now.to_i
    filter.select( db, id: id, type: FilConst::AutoRsv ).each do |t|
      row1 = filterResult.select( db, pid: t[:id] )
      proids = row1.map{|v| v[:rid] }
      id2 = id == nil ? t[:id] : id
      row2 = programs.selectSP(db, proid: proids )
      row2.each do |r|
        row3 = reserve.select(db, chid: r[:chid], evid: r[:evid] )
        if row3.size == 0
          data = {
            :id        => nil,
            :chid      => r[:chid],
            :svid      => r[:svid],
            :evid      => r[:evid],
            :title     => r[:title],
            :start     => r[:start],
            :end       => r[:end],
            :duration  => r[:duration],
            :type      => 1,
            :keyid     => id2,
            :jitan     => t[:jitan],
            :jitanExec => RsvConst::JitanOff,
            :subdir    => t[:subdir],
            #:use       => 0,
            :stat      => 0,
            :comment   => "",
            :category  => r[:categoryA][0][0],
            :dedupe    => t[:dedupe],
          }
          time = Commlib::stet_to_s( r[:start], r[:end] )
          DBlog::info(db,"自動予約: #{time[0]} #{time[1]} #{r[:title]}")
          reserve.insert(db, data )
        end
      end
    end
  end


  #
  #  一括更新
  #
  def update( sleep = true )
    st = Time.now
    searchAll( sleep )
    rsv = Reservation.new
    DBaccess.new().open do |db|
      db.transaction do
        rsv_update( db )
        rsv.check( db )
        lap = Time.now - st
        DBlog::debug( db, sprintf("FilterM::update() %.1f sec",lap ))
      end
    end
  end
  

  def search3( db, fd )

    startT = Time.now
    list = {
      pid:           "p.id",
      title:         "p.title",
    }
    para = []
    if fd[:target] == 1
      list[:detail]      = "p.detail"
      list[ :extdetail ] = "p.extdetail"
    end
    list.each_pair { |k,v| para << v }
    
    args = []
    where = []
    sql = "select " + para.join(",") +
          " from programs p inner join channel c on c.chid = p.chid "

    if fd[ :band ] > 0 and fd[ :band ] != 7
      bands = []
      bands << %Q(c.band = "GR") if fd[:band][0] != 0
      bands << %Q(c.band = "BS") if fd[:band][1] != 0
      bands << %Q(c.band = "CS") if fd[:band][2] != 0
      where << "( #{bands.join(" or " )} )"
    end

    if fd[:chanel] != nil
      chanel = []
      fd[:chanel].split.each do |ch|
        if ch == "0"
          chanel = []
          break        
        end
        chanel << %Q(c.chid = "#{ch}") 
      end
      where << "( #{chanel.join(" or " )} )" if chanel.size > 0
    end

    cate = []
    if fd[:category] != nil and fd[:category] != "0" 
      fd[:category].split.each_with_index do |tmp,n|
        if tmp == "0"
          cate = []
          break
        elsif tmp =~ /(\d+)-(\d+)/
          m = $1
          s = $2
          if s == "0"
            1.upto(3) do |n|
              cate << %Q(categoryT#{n} like "#{m}-%")
            end
          else
            1.upto(3) do |n|
              cate << %Q(categoryT#{n} = "#{m}-#{s}")
            end
          end
        end
      end
      where << "( #{cate.join(" or " )} )" if cate.size > 0
    end

    if fd[:freeonly] == RsvConst::FO
      where << "( freeCA = 0 )"
    end
    
    if where.size > 0
      sql += " where " + where.join(" and ")
      sql += " and p.start > ?"
    else
      sql += " where p.start > ?"
    end
    args << Time.new.to_i

    row = db.execute( sql, *args )
    row2 = DBprograms.new.row2hash( list, row )

    r = []
    key  = nil
    excl = nil
    fd[:key].strip! if fd[:key] != nil
    fd[:exclude].strip! if fd[:exclude] != nil
    if fd[:regex] == 0      # 単純文字列検索
      if fd[:key] != nil and fd[:key] != ""
        key = "^"
        fd[:key].split.each do |str|
          key += sprintf("(?=.*%s)",Regexp.escape(str) )
        end
      end
      if fd[:exclude] != nil and fd[:exclude] != ""
        excl = sprintf("(%s)",fd[:exclude].split.map{|v| Regexp.escape(v)}.join("|"))
      end
    else
      key = fd[:key] if fd[:key] != nil and fd[:key] != ""
      excl = fd[:exclude] if fd[:exclude] != nil and fd[:exclude] != ""
    end

    #reg = "^(?=.*ニュース)(?=.*天気)"
    key2 = Regexp.new(key) if key != nil
    excl2 = Regexp.new(excl) if excl != nil

    count = 0
    row2.each do |pd2|
      break if count >= FilConst::SeachMax

      st = pd2[:title]
      if fd[:target ] > 0
        pd2[:textall] = pd2[:title]
        pd2[:textall] += pd2[:detail] if pd2[:detail] != nil
        pd2[:textall] += pd2[:extdetail] if pd2[:extdetail] != nil
        pd2[:textall].gsub!(/\n/,'')
        st = pd2[:textall]
      end
      
      if key != nil
        if st =~ key2
          if excl == nil or !(st =~ excl2 )
            r << pd2[:pid]
            count += 1
          end
        end
      else
        if excl == nil or !(st =~ excl2 )
          r << pd2[:pid]
          count += 1
        end
      end
    end

    if $debug == true
      tmp = sprintf("search3() result = %3d time=%.3f",r.size,Time.now - startT)
      DBlog::sto( tmp )
    end

    r
  end
  

end

