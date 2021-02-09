#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  HLS モニター
#


class Monitor

  
  attr_reader :band, :list, :data, :bandname
  
  def initialize(  )

    @base_url = "/monitor"

  end

  #
  #  表示データ生成
  #
  def createData(recFlag = true)
    @list = getChData( )
    @band = @list.keys
    @bandname = { "rec" => "録画中",
                  "file" => "録画済み",
                }
    @band.each do |band|
      band2 = band == "GR" ? "地デジ" : band
      @bandname[ band ] = band2
    end
    @data = make_table( @list )

    if recFlag == true
      if ( rec = getRecData()) != nil
        title = "rec"
        @band.unshift( title )
        @data[ title ] = rec
      end
    end
  end    

  #
  #   録画済みTSファイル一覧(不使用)
  #
  def getFileData()
    paths = {}
    Find.find( TSDir ) do |path|
      if test(?f, path )
        if path =~ /\.ts$/
          if File.size( path ) > 0
            fname = path.sub( TSDir + "/" , '' )
            paths[ File.basename( fname ) ] = CGI.escape( fname )
          end
        end
      end
    end
    if paths.size > 0
      ret = []
      ret << %q(<ol>)
      paths.keys.sort.each do |path|
        id = paths[ path ]
        ret << %Q(<li> <a class="hls" href="#{@base_url}/file/#{id}"> #{path} </a> )
      end
      ret << %q(</ol>)
      return ret.join("\n")
    else
      return nil
    end
  end

  #
  #  録画中の番組を取得
  #
  def getRecData()
    paths = {}
    reserve = DBreserve.new
    DBaccess.new().open do |db|
      row = reserve.selectSP( db, stat: RsvConst::RecNow )
      row.each do |l|
        path = TSDir + "/"
        if l[:subdir] != nil and l[:subdir] != ""
          subdir2 = Commlib::normStr( l[:subdir] )
          path += subdir2.sub(/^\//,'').sub(/\/$/,'').strip + "/"
        end
        if l[:fname] != nil
          path += l[:fname]
          if test( ?f, path )
            paths[ l[:fname] ] = l[:id]
          end
        end
      end
    end

    if paths.size > 0
      ret = []
      ret << %q(<ol>)
      paths.keys.each do |path|
        id = paths[ path ]
        ret << %Q(<li> <a class="hls" href="#{@base_url}/rec/#{id}"> #{path} </a> )
      end
      ret << %q(</ol>)
      return ret.join("\n")
    else
      return nil
    end
  end

  #
  #  放送局一覧
  #
  def make_table( list )

    ret = {}
    list.keys.each do |band|
      tmp = []
      tmp << %q(<table>)  # class="striped"
      tmp << %q(<tr>)

      n = 0
      list[ band ].each_pair do |k,v|
        tmp << %Q(<td class="nowrap"> <a class="hls" href="#{@base_url}/ch/#{v}"> #{k} </a> </td>)
        n += 1
        if n > 4
          tmp << %q(</tr>)
          tmp << %q(<tr>)
          n = 0
        end
      end
      tmp << %q(</tr>)
      tmp << %q(</table>)

      ret[ band ] = tmp.join("\n")
    end
    return ret
  end

  
  #
  #  channelデータの取得
  #
  def getChData( )
    channel = DBchannel.new

    list = {}
    DBaccess.new().open do |db|
      row = channel.select( db, order: "order by band_sort,svid" )
      row.each do |r|
        next if r[:updatetime] == -1
        next if r[:skip] == 1
        list[ r[:band] ] ||= {}
        list[ r[:band] ][ r[:name] ] = r[:chid ]
      end
    end
    list
  end
  
  
end
