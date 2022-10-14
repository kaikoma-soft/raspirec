#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  予約一覧
#


class ReservationListOld

  Base = "/rsv_list_old"
  
  def initialize( params, page )
    @serach = nil
    if params["search"] != nil
      @serach = params["search"]
    end
    if page == nil
      @page = 1
    else
      @page = page.to_i
    end
    @page_line = 100            
    @autoRsv = {}               # 自動予約のIDリスト

    @reserve = DBreserve.new()
  end

  def getData()
    programs = DBprograms.new
    filter = DBfilter.new
    
    now = Time.now.to_i
    if @serach != nil
      title2 = "%#{@serach}%"
    else
      title2 = nil
    end
    DBaccess.new().open do |db|
      if (row = filter.select( db, type: FilConst::AutoRsv )) != nil
        row.each do |r|
          @autoRsv[ r[:id].to_i ] = true
        end
      end
      @total_size = @reserve.count( db, tstart: now, titleL: title2)
      @pageNum = 1
      if @total_size > @page_line
        @pageNum = @total_size / @page_line
        if @pageNum > 0
          @pageNum += 1 if (@total_size - ( @page_line * @pageNum )) > 0
        end
      end
      limit = nil
      if @pageNum > 1
        limit = "LIMIT #{@page_line} OFFSET #{@page_line * (@page - 1 )}"
      end
      order = " order by r.start desc"
      r = @reserve.selectSP( db, tstart: now, titleL: title2, limit: limit, order: order )
      return r
    end
    nil
  end

  #
  #  pageのセレクト
  #
  def pageSel( )
    r = []
    r << %Q{<ul class="pagination inline-block">}
    1.upto( @pageNum ) do |p|
      cl = "waves-effect"
      cl += " active" if @page == p
      href = sprintf("%s/%d",Base,p)
      r << %Q{    <li class="#{cl}"><a href="#{href}">#{p}</a></li>}
    end
    r << %Q{</ul>}
    
    r.join("\n")
  end

  
  def printTD( str, clas: nil, id: nil, rid: nil, style: nil )
    attr = ""
    attr += %Q{class="#{clas.join(" ")}" } if clas != nil
    attr += %Q{id="#{id}" } if id != nil
    attr += %Q{rid="#{rid}" } if rid != nil
    attr += %Q{style="#{style}" } if style != nil
    %Q{ <td #{attr}> #{str} </td>}
  end

  def printTR( data, id: nil, clas: nil )
    attr = []
    attr << %Q(class="#{clas.join(" ")}") if clas != nil
    attr << %Q(id="#{id}") if id != nil
    
    a = [ %Q{ <tr #{attr.join(" ")}> } ]
    a += data
    a << %Q{ </tr> }
    a.join("\n")
  end

  #
  #  データの表示
  #
  def printTable()
    r = []

    data = getData()
    if data != nil
      count = @page > 1 ? ( @page_line * ( @page - 1 ) + 1) : 1
      clas = %w( nowrap ) #item 
      data.each do |t|
        next if t[:stat] == RsvConst::RecNow
        clasS = %w( nowrap )
        time = Commlib::stet_to_s( t[:start], t[:end] )
        if t[:type] == 0
          type = "手動"
        else
          if @autoRsv[ t[:keyid] ] == true
            type = %Q(<a href="/search/fil/#{t[:keyid]}"> 自動 </a>)
          else
            type = "自動(除)"
          end
        end


        title = %Q(<a class="dialog" rid="#{t[:id]}"> #{t[:title]} </a>)
        bg = nil
        id = nil

        cate = t[:category]
        bg = %Q(color#{cate})
        ( stat, clasS, bg, recf ) = Commlib::statAna( t, clasS, bg  )

        st = ( Time.at(t[:start]) - 3600 ).strftime("%Y-%m-%d/%H")
        day = %Q(<a href="rsv_tbl/#{st}"> #{time[0]} </a>)
        time2 = %Q(<a href="rsv_tbl/#{st}"> #{time[1]} #{time[2]} </a>)
        if TSFT == true
          ftp_stat = case t[:ftp_stat]
                     when RsvConst::Ftp_Complete then "○"
                     when RsvConst::Ftp_AbNormal then "×"
                     when RsvConst::Off          then "未"
                     else "−"
                     end
        else
          ftp_stat = ""
        end

        # packectchk

        pc = "未"
        if PacketChkRun == true
          clasP = %w( nowrap center )
          if t[:stat] == RsvConst::AbNormalEnd or
            t[:stat] == RsvConst::RecStop or
            t[:stat] == RsvConst::RecStop2 or
            t[:stat] == RsvConst::NotUse or
            t[:stat] == RsvConst::NotUseA
            pc = "-"
          elsif t[:dropNum ] != nil 
            ( drer, pcr, execerror ) = @reserve.parseDropNum( t[:dropNum ] )
            if execerror > 0
              pc = "失敗"
            else
              pc = drer
              clasP << "packchk"
              if drer > PacketChk_threshold
                clasP << "alertR"
              elsif pcr > 0
                clasP << "alertY"
              end
            end
          end
        end
        
        name2 = %Q(<a href="ch_tbl/#{t[:chid]}"> #{t[:name]} </a>)
        td = []
        td << printTD( count, clas: clas )
        td << printTD( name2, clas: clas )
        td << printTD( day,clas: clas )
        td << printTD( time2,clas: clas )
        td << printTD( stat,clas: clasS, id: id )
        if TSFT == true
          td << printTD( ftp_stat,clas: clas )
        end
        if PacketChkRun == true
          if execerror == 0
            td << printTD( pc, clas: clasP, rid: t[:id] )
          else
            td << printTD( pc, clas: clasP )
          end
        end
        td << printTD( type,clas: clas )
        td << printTD( title,clas: clas )
        r << printTR( td, clas: [ bg ] )
        count += 1
      end
    end
    r.join("\n")
  end
end


