#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  ch 毎の番組表
#


class ChTbl

  Base = "/ch_tbl"

  attr_reader :name, :skip, :phch, :svid, :tt

  def initialize( chid )

    @chid = chid                # 対象チャンネル
    @tate = 24                  # 縦の長さ (H)
    @hour_pixel = 180           # 1時間の長さ (px)
    @st = 0                     # start time
    @et = @st + @tate * 3600    # end time
    @stByDay = {}
    @rsv = {}
    @chData = getPrgData( @chid )

    pto = PTOption.new
    @hour_pixel = pto.hp        # 1時間の長さ (px)
    @tt         = pto.tt        # tooltip の表示の on/off

  end

  #
  #  channelデータの取得
  #
  def getChData( db, chid )
    channel = DBchannel.new

    row = channel.select( db, chid: chid )
    if row.size > 0
      r = row.first
      @name = r[:name]
      @skip = r[:skip] == 1 ? true : false
      @svid = r[:svid]
      @phch = Commlib::makePhCh( r )
    end
  end

  #
  #  番組データの取得
  #
  def getPrgData( chid )

    programs = DBprograms.new
    reserve = DBreserve.new
    rsvData = {}
    now = Time.now
    zeroji = Time.local( now.year,now.mon,now.day ).to_i
    DBaccess.new().open do |db|
      db.transaction do
        getChData( db, chid )
        row = programs.selectSP(db, chid: chid, tend: zeroji )
        row.each do |r|
          day = Commlib::stet_to_s( r[:start], r[:end] )[0]
          t = Time.at(r[:start])
          @stByDay[ day ] = Time.local( t.year,t.mon,t.day )
          rsvData[ day ] ||= []
          rsvData[ day ] << r
        end

        row = reserve.selectSP( db ) # stat: RsvConst::ActStat
        row.each do |tmp|
          @rsv[ tmp[:chid] ] ||= {}
          @rsv[ tmp[:chid] ][ tmp[:evid] ] = tmp[:stat]
        end

      end
    end

    rsvData
  end


  #
  #  縦軸(時間)の生成
  #
  def tatejiku()
    r = []
    24.times.each  do |n|
      height = @hour_pixel - 4
      height += 3 if n == 0
      adj = "style=height:#{height}px;"
      r << sprintf(%Q{<div class='time' %s> %d </div>},adj, n )
    end
    r.join("\n")
  end

  #
  #  横軸(日付)の生成
  #
  def yokojiku()
    r = []
    now = Time.now
    zeroji = Time.local( now.year,now.mon,now.day ).to_i
    @chData.keys.sort.each do |day|
      next if @stByDay[day].to_i < zeroji
      r << sprintf(%Q{<div class='station'> %s </div>}, day)
    end
    r.join("\n")
  end

  def printItem( time, text, cls: nil, pid: nil, tip: nil )
    px = ((( time ).to_f / 3600 ) *  @hour_pixel ).to_i
    style = sprintf(%Q{style="height:%dpx;" },px)
    cls2 = cls != nil ? %Q{class='#{cls.join(" ")}'} : ""
    tip2 = tip != nil ? %Q{data-text="#{tip}"} : ""
    pid2 = pid != nil ? %Q{pid="#{pid}"} : ""
    moni = %Q(moni="off")

    sprintf(%Q{  <div %s %s %s %s %s> %s </div>},cls2, pid2,tip2,style,  moni,text )
  end

  #
  #  表
  #
  def prgTable( chid )
    r = []
    overlap = nil
    now = Time.now
    zeroji = Time.local( now.year,now.mon,now.day ).to_i
    @chData.keys.sort.each do |day|
      ct = @stByDay[day].to_i      # current time
      if ct < zeroji
        overlap = @chData[day].last
        next
      end
      et = ct + @tate * 3600
      r << sprintf(%Q{<div class='dtc'>})
      if @chData[day] == nil
        cls = [ "colorGray" ]
        r << printItem( ( et - ct), "&nbsp;", cls: cls  )
      else
        if overlap != nil
          @chData[day].unshift( overlap )
        end
        @chData[day].each do |tmp|
          hosei = 0
          if tmp[:start ] > ct # ダミーの挿入
            cls = [ "colorGray" ]
            r << printItem( (tmp[:start ] - ct), "&nbsp;", cls: cls  )
            ct = tmp[:start ]
          elsif tmp[:start ] < ct
            hosei = tmp[:start ] - ct
          end
          if tmp[:end] > et
            hosei -= ( tmp[:end] - et )
          end
          l = tmp[:end] - tmp[:start] + hosei

          cls = [ "item", sprintf("color%d",tmp[:categoryA][0][0]) ]

          if @rsv[chid] != nil and @rsv[chid][tmp[:evid]] != nil
            stat = @rsv[chid][tmp[:evid]]
            cls << case stat
                   when RsvConst::Normal, RsvConst::RecNow
                   then "alertR"
                   when RsvConst::NotUse, RsvConst::RecStop,RsvConst::RecStop2
                   then "alertBD"
                   end
            # if stat == RsvConst::Normal or stat == RsvConst::RecNow
            #   cls << "alertR"
            # elsif stat == RsvConst::NotUse or
            #      stat == RsvConst::RecStop or
            #      stat == RsvConst::RecStop2
            #   cls << "alertBD"
            # end
          elsif tmp[:jitanExe] == RsvConst::JitanEOn
            cls << "alertGD"
          end

          chname= tmp[:name]
          rid   = tmp[:id]
          pid   = tmp[:pid]
          title = tmp[:title].gsub(/\"/,"&quot;")

          stime = Time.at( tmp[:start] ).strftime("%H:%M")
          etime = Time.at( tmp[:end] ).strftime("%H:%M")
          tip   = %Q{#{chname}<br>#{title}<br>#{stime} 〜 #{etime}}
          r << printItem( l, title, pid: pid, tip: tip, cls: cls )

          ct = tmp[:end]
          if tmp[:end] > et
            overlap = tmp
          else
            overlap = nil
          end
        end
        if et > ct
          cls = [ "colorGray" ]
          r << printItem( ( et - ct), "&nbsp;", cls: cls  )
        end
      end
      r << sprintf(%Q{</div>})
    end
    r.join("\n")
  end


end
