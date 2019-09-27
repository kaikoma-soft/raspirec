#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  フィルター削除 ダイアログ
#


class FilterListD

  attr_reader :title
  
  def initialize( id )
    @id = id
    @title = ""

    DBaccess.new().open do |db|
      filter = DBfilter.new()
      data = filter.select( db, id: @id )
      if data.size > 0
        d = data.first
        if d[:title] == nil or d[:title] == ""
          @title = d[:key]
        else
          @title = d[:title]
        end
      end
    end
  end


end

