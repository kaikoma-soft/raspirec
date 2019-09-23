#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  カテゴリの配色表
#


class Cate_color

  def initialize( )

  end

  def printTable2( title, val, id = nil)
    color = sprintf("color%d",val )
    sprintf(%Q{<tr class="#{color}"> <td class="nowrap" > %s </td><td> %s </td>},title, color)
  end

  
  def printTable()
    r = []

    row = nil
    category = DBcategory.new
    DBaccess.new(DbFname).open do |db|
      row = category.selectL( db )
      if row != nil and row.size > 0
        row.each do |tmp|
          r << printTable2( tmp[:name], tmp[:id] )
        end
      end
    end
    r.join("\n")
  end
end

