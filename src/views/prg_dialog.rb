#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  番組詳細
#


class Dialog_pid

  Base = "/prgtbl"
  
  def initialize( pid )
    @pid = pid
  end

  def printTable2( title, val)
    sprintf(%Q{<tr> <td class="nowrap" > %s </td><td> %s </td>},title, val)
  end

  def extdetail2table( data )
    r = []
    r << %Q{<table calss="striped">}
    data.each do |tmp|
      title = tmp[ "item_description" ]
      item  = tmp[ "item" ]
      r << %Q{  <tr>}
      r << %Q{    <td class="nowrap fss"> #{title} </td> <td class="fss"> #{item} </td> }
      r << %Q{  </tr>}
    end
    r << %Q{</table>}

    r.join("\n")
  end


  
  def getData()
    row = nil
    programs = DBprograms.new()
    category = DBcategory.new( )

    DBaccess.new(DbFname).open do |db|
      data = programs.selectSP( db, proid: @pid )
      if data.size > 0
        data2 = data.first
        cate = []
        data2[:categoryA].each do |tmp|
          if tmp[0] != 0
            cate << category.conv2str(db, tmp[0],tmp[1] ).join(" ： ")
          end
        end
        return [ data2,cate ]
      end
    end
    [ nil, nil ]
  end

  #
  #  データの表示
  #
  def printTable()
    r = []

    ( tmp, cate ) = getData()    
    if tmp != nil and tmp.size > 0
      r << printTable2("放送局名", tmp[:name]  + " (#{tmp[:chid]})" )
      r << printTable2("番組名",   tmp[:title] + " (evid=#{tmp[:evid]})" )
      r << printTable2("概要",     tmp[:detail] ) if tmp[:detail].strip != ""
      r << printTable2("録画時間", Commlib::stet_to_s( tmp[:start], tmp[:end] ).join(" "))
      
      if cate.size > 0
        r << printTable2("分類", cate.join("<br>\n") )
      end
        
      if tmp[:extdetail] != nil and tmp[:extdetail].strip != ""
        if ( data = YamlWrap.load( tmp[:extdetail])).size > 0
          r << printTable2("詳細情報", extdetail2table( data ))
        end
      end
    end
    r.join("\n")
  end
end

