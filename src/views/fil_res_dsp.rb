#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  フィルター検索結果の表示
#

class FilterDisp

  def initialize( params )
    @freeOnly = params["FO"] == "on" ? true : false
  end

  def filter?()
    return @fa_flag == 0 ? true : false
  end
  
  def fo?()
    return @freeOnly
  end
  
  #
  #  データの表示
  #
  def print( id, session )
    r = {}
    prog = DBprograms.new
    filresR = DBfilterResult.new
    reserve = DBreserve.new
    filter = DBfilter.new
    now = Time.now.to_i
    DBaccess.new().open do |db|
      data = filter.select( db, id: id )
      if data[0] != nil
        @fa_flag = data[0][:type] == FilConst::Filter ? 0 : 1
        data = filresR.select(db, pid: id )
        data2 = data.map{|v| v[:rid] }
        data3 = prog.selectSP( db, proid: data2 )
        count = 1
        total = data.size
        tmp = []
        tdclas = [ "item" ]
        data3.each do |t|
          next if t[:end] < now
          (day, time, w) = Commlib::stet_to_s( t[:start], t[:end] )
          cate = t[:categoryA][0][0]
          trcl = %W(color#{cate})
          res = reserve.select( db, evid: t[:evid], chid: t[:chid] )
          res2 =  ""
          resid = nil
          if res.size > 0
            if @freeOnly == true
              total -= 1
              next
            end
            if res[0][:stat] == RsvConst::Normal or res[0][:stat] == RsvConst::RecNow
              res2 = "○"
            else
              res2 = "×"
            end
            resid = res[0][:id]
          end
          name = %Q(<a href="/ch_tbl/#{t[:chid]}"> #{t[:name]}</a>)
          data = [ count,name, day,time,res2,t[:title],t[:detail] ]
          tmp << Commlib::printTR2( data, rid: t[:pid], trcl: trcl, tdcl: tdclas, tdclf: 2, resid: resid )
          count += 1
        end
        r[:title] = sprintf("<h1 id=\"title\" fa_flag=\"#{@fa_flag}\">検索結果 %d 件</h1>", total )
          
        r[:table] = tmp.join("\n")
      end
    end
    r
  end

end

