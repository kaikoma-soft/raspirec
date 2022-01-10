#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  フィルター一覧
#

class FilterList

  attr_reader :type, :radioST
  
  def initialize( params, session = nil )
    @params = params
    @session = session
    if @session != nil
      @fa_type = @session["fa_type"]
      @type = @fa_type == :autoRsv ? FilConst::AutoRsv : FilConst::Filter
    else
      raise "session unkown"
    end

    #
    # sort_type の保存/取得
    #
    @sort_type = case params["sort_type"]
                 when "title"   then  ARSort::Title
                 when "reg"     then  ARSort::Reg
                 when "cate"    then  ARSort::Cate
                 when "num"     then  ARSort::Num
                 end
    @sort_reverse = case params["reverse"]
                    when "off" then ARSort::Off
                    when "on"  then ARSort::On
                    end
    DBaccess.new().open do |db|
      if @type == FilConst::AutoRsv
        type_name = ARSort::KeyNameT
        reverse_name = ARSort::KeyNameR
      else
        type_name = FilSort::KeyNameT
        reverse_name = FilSort::KeyNameR
      end
      keyval = DBkeyval.new
      if @sort_type == nil
        @sort_type = keyval.select( db, type_name )
      else
        keyval.upsert( db, type_name, @sort_type )
      end
      if @sort_reverse == nil
        @sort_reverse = keyval.select( db, reverse_name )
      else
        keyval.upsert( db, reverse_name, @sort_reverse )
      end
    end

    @sort_type = ARSort::Title if @sort_type == nil
    @sort_reverse = ARSort::Off if @sort_reverse == nil
    @radioST = Array.new( 4 + 1, false )
    @radioST[ @sort_type ] = true
    @radioST[ ARSort::Reverse ] = true if @sort_reverse == ARSort::On
    
  end

  #
  #  表示データの取得
  #
  def getData()
    data = nil
    DBaccess.new().open do |db|
      filter   = DBfilter.new()
      category = DBcategory.new()
      reserve  = DBreserve.new()
      
      data = filter.select( db, type: @type )
      if @type == FilConst::AutoRsv
        rsvd = reserve.select( db, stat: RsvConst::Normal )
        rsvd2 = {}
        rsvd.each do |tmp|
          id = tmp[:keyid]
          rsvd2[id] = 0 if rsvd2[id] == nil
          rsvd2[id] += 1
        end
        data.each do |tmp|
          id = tmp[:id]
          if rsvd2[id] == nil
            tmp[:result2] = 0
          else
            tmp[:result2] = rsvd2[id]
          end
        end
      end

      # カテゴリの文字列化
      data.each do |t|
        t[:cate] = category.ids2str(db, t[:category] )
      end
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

      case @sort_type
      when ARSort::Title then data.sort_by! {|a| [a[:title2],a[:id]] }
      when ARSort::Reg   then data.sort_by! {|a| a[:id] }
      when ARSort::Cate  then data.sort_by! {|a| [a[:cate], a[:title2]] }
      when ARSort::Num   then data.sort_by! {|a| [a[:result2], a[:result],a[:title2]] }
      end
      if @sort_reverse == ARSort::On
        data.reverse!
      end
      data.each do |t|
        b = sprintf( b1 + b2 + b3, t[:id],t[:id],t[:id] )
        title = ( t[:title] != nil and t[:title] != "" )? t[:title] : t[:key]

        r1 = zeroRed( t[:result] )
        r2 = zeroRed( t[:result2] )
        if @type == FilConst::AutoRsv
          result = sprintf( "%s/%s", r2, r1 )
        else
          result = sprintf( "%s", r1 )
        end

        r << printTR( t[:id], classs, count, title, t[:cate], result, b )
        count += 1
      end
    end
    r.join("\n")
  end

  def zeroRed( val )
    if val == 0
      return %Q( <font color="red" > #{val} </font>)
    else
      return val.to_s
    end
  end
end
  
