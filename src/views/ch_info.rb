#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  ch 情報
#


class ChaneruInfo

  attr_reader :name, :skip, :phch, :svid, :tt

  def initialize( )
    ( @data,  @chid_prog ) = getChData( )
    @older = 3600 * 24 * 31     # 1ヶ月
  end

  #
  #  channelデータの取得
  #
  def getChData( )
    ret = nil
    chid_prog = {}
    DBaccess.new().open do |db|
      channel = DBchannel.new
      ret = channel.select( db, order: "order by band_sort,chid"  )

      # 過去から全ての予約数
      reserve = DBreserve.new
      prog = reserve.select( db )
      prog.each do |tmp|
        chid_prog[ tmp[:chid] ] ||= 0
        chid_prog[ tmp[:chid] ] += 1
      end
    end
    [ ret, chid_prog ]
  end

  #
  #  表
  #
  def printTable()
    ret = []
    n = 1
    b = %Q(<a class="btn btn-small waves-effect waves-light item %s" href="/ch_info/del" chid="%s">削除</a>)

    now = Time.now.to_i
    @data.each do |d|
      t = d[:updatetime].to_i
      next if t == -1
      color = now - t > @older ? "color9" : ""
      date = t == 0 ? "-" : Time.at( t ).strftime("%Y-%m-%d %H:%M:%S")
      skip = d[:skip] == 1 ? "On" : "-"
      count = @chid_prog[ d[:chid] ] == nil ? 0 : @chid_prog[ d[:chid] ]
      #del = sprintf( b, count == 0 ? "" : "disabled" , d[:chid], )
      del = sprintf( b, "", d[:chid], )

      arg = [ n, d[:band], d[:chid], d[:name],d[:tsid],d[:onid],
              d[:svid],d[:stinfo_tp],d[:stinfo_slot], skip, date, count, del]
      ret << Commlib::printTR2( arg, trcl: [color] )
      n += 1
    end
    ret.join()
  end

  #
  #  EPG パッチデータ
  #
  def epgPatchTable()

    ret = []
    if $epgPatch == nil
      $epgPatch = EpgPatch.new.getData()
    end

    $epgPatch.each_pair do |k,v|
      v.each_pair do |k2,v2|
        arg = [ k, k2, v2 ]
        ret << Commlib::printTR2( arg )
      end
    end
    ret.join()

  end



end
