#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  フィルター検索結果
#


class FilterTest

  def initialize( id, params, session )
    @id = id
    @params = params
    @session = session
    if @session != nil
      @fa_type = @session["fa_type"]
    end
  end

  #
  #  試行ボタン
  #
  def testrun(params)
    r = []
    fp = FilterM.new()
    d = fp.formAna( params )
    programs = DBprograms.new
    reserve = DBreserve.new
    DBaccess.new().open do |db|
      r2 = fp.search3( db, d )
      data = nil
      data = programs.selectSP( db, proid: r2 )
      size = sprintf("%d 件",data.size )
      size += "以上" if data.size == FilConst::SeachMax
      r << sprintf("<h1 id=\"title\" fa_flag=\"0\">検索結果 %s </h1>", size)

      tdclas = [ "nowrap","item" ]
      data.each_with_index do |t, n |
        (day, time, w) = Commlib::stet_to_s( t[:start], t[:end] )
        cate = t[:categoryA][0][0]
        trcl = %W(color#{cate})
        res = reserve.select( db, evid: t[:evid], chid: t[:chid] )
        res2 =  ""
        if res.size > 0
          if res[0][:stat] == RsvConst::Normal
            res2 = "○"
          else
            res2 = "×"
          end
        end
        data = [ n+1,t[:name], day,time, res2,t[:title],t[:detail] ]
        r << Commlib::printTR2( data, rid: t[:pid], trcl: trcl, tdcl: tdclas, )
      end
    end
    r.join("\n")
  end

  
end



