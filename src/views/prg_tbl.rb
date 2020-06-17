#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  番組表
#


class PrgTbl

  Base = "/prg_tbl"

  attr_reader :tt
  
  def initialize( band , date,time )

    @time = nil                 # カレント時間
    if date != nil and time != nil
      if date =~ /(\d+)-(\d+)-(\d+)/
        y = $1.to_i
        m = $2.to_i
        d = $3.to_i
        h = time.to_i
        @time = Time.local( y,m,d,h)
      end
    end
    if @time == nil
      ta = Time.now.to_a
      @time = Time.local( ta[5],ta[4],ta[3],ta[2]) 
    end

    pto = PTOption.new
    @page_limit = pto.sp        # 1ページ当たりの放送局数 (個)
    @hour_pixel = pto.hp        # 1時間の長さ (px)
    @tate       = pto.hn        # 縦の長さ (H)
    @tt         = pto.tt        # tooltip の表示の on/off
    
    ( @chData, @prgData, @rsvData ) = getPrgData( @time )

    if band == nil
      @band = @chData.keys.first
      @page = 0
    else
      if band =~ /^(\D+)(\d+)$/
        @band = $1
        @page = $2.to_i
      else
        @band = band
        @page = 0
      end
    end
    
  end

  #
  #  現在時間を示す線
  #
  def nowLine()

    if @chData[ @band ] != nil
      stationN = @chData[ @band ][ @page ].size
      stationW = 160 + 5
      Commlib::nowLine( @time, @tate, @hour_pixel, stationN, stationW, -10 )
    end
  end

  
  #
  #  番組データの取得
  #
  def getPrgData( time = Time.now )
    start = time.to_i
    fin   = ( start + @tate * 3600 ).to_i
    root = {}
    prgs = {}
    rsv = {}
    programs = DBprograms.new
    reserve = DBreserve.new
    DBaccess.new(DbFname).open do |db|
      order = "order by c.band_sort,c.svid,p.start"
      row = programs.selectSP( db, tstart: start, tend: fin, order: order, skip: 0 )

      if row != nil
        row.each do |tmp|
          band  = tmp[:band]
          cname = tmp[:name]
          chid = tmp[ :chid ]
          root[ band ] ||= {}
          root[ band ][chid] ||= {}
          root[ band ][chid] = cname
          tmp[:cate1m ] = tmp[:categoryA][0][0]
          tmp[:cate1s ] = tmp[:categoryA][0][1]
          prgs[ band ] ||= {}
          prgs[ band ][ chid ] ||= []
          prgs[ band ][ chid ] << tmp
        end
      end

      row = reserve.select(db, tstart: start, tend: fin)
      row.each do |tmp|
        rsv[ tmp[:chid] ] ||= {}
        rsv[ tmp[:chid] ][ tmp[:evid] ] = tmp[:stat]
      end
    end
    
    #
    #  root2 = [band(Hash)][page][cname,sid] に変形
    #
    root2 = {}
    root.keys.each do |band|
      tmp = root[ band ].to_a
      root2[band] = tmp.each_slice( @page_limit ).to_a
    end

    [ root2 , prgs, rsv  ]
  end

  #
  #    時間指定の生成
  #
  def getTimeHref()
    ymd = @time.strftime("%Y-%m-%d")
    r = []
    band = @band + @page.to_s
    r << sprintf("%s/%s/%s/%02d",Base,band,ymd, 5 )
    r << sprintf("%s/%s/%s/%02d",Base,band,ymd, 11 )
    r << sprintf("%s/%s/%s/%02d",Base,band,ymd, 17 )
    r << sprintf("%s/%s/%s/%02d",Base,band,ymd, 23 )
    t = @time - 3600 * 3 
    r << sprintf("%s/%s/%s",Base,band, t.strftime("%Y-%m-%d/%H"))
    t =  @time + 3600 * 3 
    r << sprintf("%s/%s/%s",Base,band, t.strftime("%Y-%m-%d/%H"))
    r
  end
  
  #
  #  バンドのセレクト
  #
  def bandSel( )
    r = []
    date = @time.strftime("%Y-%m-%d/%H")

    str =  @band == "GR" ? Const::GRJ : @band
    r << %Q(<a class='dropdown-trigger btn col' id='band' data-target='dropdown2' href='#'> #{str} </a> )
    r << %Q(<ul class='dropdown-content' id='dropdown2'>)
    @chData.keys.each do |b|
      str =  b == "GR" ? Const::GRJ : b
      href = sprintf("%s/%s%d/%s",Base, b, 0, date )
      r << %Q(<li> <a href='#{href}'> #{str} </a> </li>)
    end
    r << %Q{</ul>}
    r.join("\n")
  end
  
  #
  #  pageのセレクト
  #
  def pageSel( )
    r = []
    date = @time.strftime("%Y-%m-%d/%H")
    @chData.keys.each do |b|
      if @band == b
        r << %Q{<ul class="pagination inline-block">}
        0.upto( @chData[ b ].size - 1 ) do |p|
          cl = "waves-effect"
          cl += " active" if @page == p
          href = sprintf("%s/%s%d/%s",Base,b,p,date )
          r << %Q{    <li class="#{cl}"><a href="#{href}">#{p+1}</a></li>}
        end
        r << %Q{</ul>}
      end
    end

    r.join("\n")
  end
  
  
  #
  # 日付指定の Badges in Dropdown
  #
  def dateSel(  )
    dow = Const::Wday
    now = Time.now
    tmp = []
    target = @time.strftime("%m/%d ") + dow[ @time.wday ]
    8.times do |n|
      t = now.strftime("%m/%d ") + dow[ now.wday ]
      href = sprintf("%s/%s%d/%s/%s",
                     Base,@band,@page,
                     now.strftime("%Y-%m-%d"),
                     @time.strftime("%H") )
      tmp << [ t, href ]
      now += 3600 * 24
    end

    r = []
    t = @day
    r << %Q{<a class='dropdown-trigger btn col' id='date' data-target='dropdown1' href='#'> #{target}</a>}
    r << %Q{<ul class='dropdown-content' id='dropdown1'>}
    tmp.each do |tmp2|
      r << %Q{   <li> <a href='#{tmp2[1]}'>#{tmp2[0]}</a> </li>}
    end
    r << %Q{</ul>}
    r.join("\n")
  end

  #
  #  縦軸(時間)の生成
  #
  def tatejiku()
    t = @time
    r = []
    @tate.times.each  do |n|
      height = @hour_pixel - 4
      height += 3 if n == 0
      adj = "style=height:#{height}px;"
      r << sprintf(%Q{<div class='time' %s> %s </div>},adj, t.strftime("%H"))
      t += 3600
    end
    r.join("\n")
  end

  #
  #  横軸(放送局)の生成
  #
  def yokojiku()
    r = []
    if @chData[ @band ] != nil and @chData[ @band ][ @page ] != nil
      @chData[ @band ][ @page ].each do |tmp|
        str = sprintf(%Q(<a href="/ch_tbl/%s"> %s </a>),tmp[0],tmp[1] )
        r << sprintf(%Q{<div class='station'> %s </div>},str)
      end
    end
    r.join("\n")
  end

   # ダミー項目の挿入
  def insDummy( px )
  end

  
  #
  #  プログラム表
  #
  def prgTable()
    r = []

    st = @time.to_i             # start time
    et = st + @tate * 3600      # end time
    now = Time.now.to_i
    moni = false
    if MPMonitor == true        # チュナー数に余裕があるか
      if $mpvMon != nil
        if $mpvMon.autoSel( @band ) != nil
          moni = true
        end
      end
    end

    return "" if @chData[ @band ] == nil or @chData[ @band ][ @page ] == nil
    @chData[ @band ][ @page ].each do |ch|
      ct = st                     # current time
      sid = ch[0]
      r << sprintf(%Q{<div class='dtc'>})

      @prgData[ @band ][ sid ].each_with_index do |tmp,n|

        hosei = 0
        if tmp[:start ] > ct # ダミーの挿入
          px = (( (tmp[:start ] - ct ).to_f / 3600 ) *  @hour_pixel ).to_i
          style = sprintf(%Q{style="height:%dpx;" },px)
          r << sprintf(%Q{  <div class='' %s> %s </div>},
                       style, "&nbsp;")
          ct = tmp[:start ]
        elsif tmp[:start ] < ct
          hosei = tmp[:start ] - ct
        end
        if tmp[:end] > et
          hosei -= ( tmp[:end] - et )
        end
        l = tmp[:end] - tmp[:start] + hosei

        cls = [ "item", sprintf("color%d",tmp[:cate1m]) ]
        if @rsvData[ tmp[:chid] ] != nil
          if @rsvData[ tmp[:chid] ][ tmp[:evid] ] != nil
            if @rsvData[ tmp[:chid] ][ tmp[:evid] ] == 0
              cls << "alertR"
            else
              cls << "alertBD"
            end
          end
        end
                
        px = (( l.to_f / 3600 ) *  @hour_pixel ).to_i
        style = sprintf(%Q{style="height:%dpx;" },px)
        pid   = sprintf(%Q{pid="%d" }, tmp[:pid])
        stime = Time.at( tmp[:start] ).strftime("%H:%M")
        etime = Time.at( tmp[:end] ).strftime("%H:%M")
        moni2 = "off"
        if moni == true
          if tmp[:start] < now and now < tmp[:end]
            moni2 = "/mpv_mon/auto/ch/#{tmp[:chid]}"
          end
        end
        moni3 = sprintf(%Q{moni="%s"}, moni2)
        tip   = sprintf(%Q{data-tooltip="%s<br>%s 〜 %s"},tmp[:title],stime,etime)
        r << sprintf(%Q{  <div class='%s' %s %s %s %s> %s </div>},
                     cls.join(" "), style,pid, moni3, tip, tmp[:title])

        ct = tmp[:end]
      end
      r << sprintf(%Q{</div>})
    end
    r.join("\n")
  end

  def colors()
    colors = %w( b3e5fc #d1c4e9 #ffcdd2 #e1bee7 #bbdefb #b2dfdb #c8e6c9 #f0f4c3  #fff9c4 #ffe0b2 #ffccbc #d7ccc8 #b2ff59 #69f0ae #a7ffeb #ff8a80 #b388ff #82b1ff #8c9eff )
    
    r = []
    
    r << %Q{<style type="text/css">}
    colors.each_with_index do |color,n|
      r << sprintf("#color%d {\n\tborder:  solid 1px %s;\n\tbackground-color:%s;\n}",n,"#999",color )
    end
    r << %Q{</style">}
    r.join("\n")
  end

  #
  #  form の初期パラメータ設定
  #
  def setFormPara()
    d = {}
    d[:jitanchk] = true
    d[:dirs]  = Commlib::datalist_dir()
    d
  end

  def tooltip_sw()
    buff = [ ]
    val = @tt == false ? "true" : "false"
    buff = <<EOS
<script>   
    $(document).ready(function() { 
       $(".item").tooltip( "option", "disabled", #{val} );
    });
</script>
EOS
    buff
  end
  
  
end

