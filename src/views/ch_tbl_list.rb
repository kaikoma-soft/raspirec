#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  ch 毎の番組表
#


class ChTblList

  Base = "/ch_tbl"
  
  def initialize(  )
    @tate = 24
    @ret = {}
    channel = DBchannel.new
    DBaccess.new().open() do |db|
      row = channel.select(db, order: "order by svid")
      row.each do |r|
        next if r[:updatetime] == -1
        cl = r[:skip] == 0 ? "disp" : "skip"
        tmp = sprintf(%Q{ <a class="%s" href=#{Base}/%s > %s </a> },cl,r[:chid],r[:name])
        @ret[ r[:band] ] ||= []
        @ret[ r[:band] ] <<  tmp
      end
    end

  end

  #
  #  表
  #
  def printTable(  )
    r = []
    tmp = {}
    %w( GR BS CS ).each do |band|
      n = 0
      tmp[ band ] ||= {}
      tmp[ band ][ n ] ||= []
      
      if @ret[band] != nil and @ret[band].size > @tate
        @ret[band].each_slice( @tate ) do |part|
          tmp[ band ][ n ] ||= []
          tmp[ band ][ n ] = part
          n += 1
        end
      else
        tmp[ band ][ n ] = @ret[band]
      end
    end
    
    r << "<tr>"
    tmp.keys.each do |band|
      size = tmp[band].size
      r << %Q(<th colspan="#{size}"> #{band}  </th>)
    end
    r << "</tr>"
    
    while true
      r << "<tr>"
      count = 0
      tmp.keys.each do |band|
        tmp[band].keys.each do |n|
          if tmp[band][n] != nil
            d = tmp[band][n].shift
            if d != nil
              r << "<td>" + d + "</td>"
              count += 1
            else
              r << "<td><br></td>"
            end
          end
        end
      end
      r << "</tr>"
      break if count == 0
    end
    r.join("\n")
  end

  
end
