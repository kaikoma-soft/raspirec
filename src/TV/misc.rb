# coding: utf-8

#
#  raspirecTV.rb 関連
#

#
#  チャンネル情報
#
class ChList

  def initialize()
    @phch = {}
    @chList = {}
    channel = DBchannel.new
    DBaccess.new().open do |db|
      row = channel.select( db, order: "order by band_sort,svid" )
      row.each do |r|
        next if r[:updatetime] == -1
        next if r[:skip] == 1
        chid = r[:chid ]
        tmp = Commlib::makePhCh( r )
        band = r[:band]
        @phch[ chid ] = ChInfo.new(phch: tmp, svid: r[:svid], band: band, chname: r[:name] )
        @chList[ band ] ||= {}
        @chList[ band ][ r[:name]] = chid
      end
    end
  end

  def getChList()
    return @chList
  end

  def getPhCh( chid )
    return @phch[ chid ]
  end
end

#
#  番組情報の取得
#
class Prog

  attr_reader  :data
  def getData( chid )
    if @updTime == nil or @updTime < Time.now.to_i
      getInfo()
    end
    return @data[ chid ]
  end

  def getDetail( chid )
    tmp = @data[ chid ]
    if tmp != nil
      ret = "\n" + tmp.prog_name + "\n\n"
      ret += Commlib::stet_to_s( tmp.start, tmp.endt ).join(" ") + "\n\n"
      if tmp.prog_detail != nil
        ret += tmp.prog_detail + "\n"
      end
      if tmp.prog_extdetail != nil and tmp.prog_extdetail.strip != ""
        if ( data = YAML.load( tmp.prog_extdetail)).size > 0
          ret += "\n-----  詳細情報  ------\n" 
          data.each do |tmp|
            title = tmp[ "item_description" ]
            item  = tmp[ "item" ]
            ret += "<<< #{title} >>>\n"
            ret += item + "\n\n"
          end
        end
      end
    else
      ret = ""
    end

    return ret
  end
  
  def getInfo(  )
    @data = {}
    @updTime = nil
    programs = DBprograms.new
    DBaccess.new().open do |db|
      now = Time.now.to_i
      row = programs.selectSP( db, tstart: now, tend: now )
      row.each do |r1|
        chid = r1[:chid]
        @data[chid] = ChInfo.new( prog_name: r1[:title],
                                  prog_detail: r1[:detail],
                                  prog_extdetail: r1[:extdetail],
                                  start: r1[:start],
                                  endt:  r1[:end],
                                  chname: r1[:name]
                                )
        if @updTime == nil or @updTime > r1[:end]
          @updTime = r1[:end]
          #pp Time.at( @updTime ).to_s + " " + r1[:title]
        end
      end
    end
  end
end

class ChInfo
  attr_accessor   :prog_name, :prog_detail, :prog_extdetail, :phch, :svid, :band
  attr_accessor   :start, :endt, :chname
  
  def initialize( prog_name:   nil,
                  prog_detail: nil,
                  prog_extdetail: nil,
                  start:       nil,
                  endt:         nil,
                  phch:        nil,
                  svid:        nil,
                  band:        nil,
                  chname:      nil
                )
    @prog_name   = prog_name
    @prog_detail = prog_detail
    @prog_extdetail = prog_extdetail
    @phch        = phch
    @svid        = svid
    @band        = band
    @start       = start
    @endt        = endt
    @chname      = chname

  end
end



