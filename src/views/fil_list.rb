#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  フィルター一覧
#



class FilterList

  def initialize( params, session = nil )
    @params = params
    @session = session
    if @session != nil
      @fa_type = @session["fa_type"]
      @type = @fa_type == :autoRsv ? FilConst::AutoRsv : FilConst::Filter
    else
      raise "session unkown"
    end
  end

  #
  #  表示データの取得
  #
  def getData()
    data = nil
    DBaccess.new().open do |db|
      filter = DBfilter.new()
      data = filter.select( db, type: @type )
    end
    data
  end

  #
  # タイトル
  #
  def printTitle()
    if @session["fa_type"] == :autoRsv
      return "自動予約一覧"
    else
      return "フィルター一覧"
    end
  end
  
  def printTR( rid, cl, *arg )

    cls = "class=\"" + cl.join(" ") + "\""
    rids = "rid=\"#{rid}\""
    a = [ %Q{ <tr> } ]
    arg.each do |tmp|
      a << %Q{ <td #{cls} #{rids}> #{tmp} </td>}
    end
    a << %Q{ </tr> }
    a.join("\n")
  end

  #
  #  データの表示
  #
  def printTable()
    r = []
    b1 = %Q(<a class="btn btn-small waves-effect waves-light" href="/fil_res_dsp/%d" id="button">表示</a>)
    b2 = %Q(<a class="btn btn-small waves-effect waves-light" href="/search/fil/%s" id="button">変更</a>)
    b3 = %Q(<a class="btn btn-small waves-effect waves-light item" href="/fil_del/" id="button" rid="%s">削除</a>)

    data = getData()    
    if data != nil
      data.each do |t|
        t[:title2] = (t[:title].nil? || t[:title].empty?) ? t[:key] : t[:title] 
      end
      count = 1
      classs = %w( nowrap )
      data.sort do |a,b|
        a[:title2] <=> b[:title2]
      end.each do |t|
        b = sprintf( b1 + b2 + b3, t[:id],t[:id],t[:id] )
        title = ( t[:title] != nil and t[:title] != "" )? t[:title] : t[:key]
        if t[:result] == 0
          result = %Q( <font color="red" > #{t[:result]} </font>)
        else
          result = t[:result]
        end
        r << printTR( t[:id], classs, count, title,result, b )
        count += 1
      end
    end
    r.join("\n")
  end
end

