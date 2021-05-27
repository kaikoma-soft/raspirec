#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#
#


module Commlib

  #
  #  chid から band を判定
  #
  def chid2band( chid )
    band = case chid
           when /^GR/ then Const::GR 
           when /^BS/ then Const::BSCS
           when /^CS/ then Const::BSCS
           when /^\d+$/ then
             n = chid.to_i
             n < 100 ? Const::GR : Const::BSCS
           end
    return band
  end
  module_function :chid2band
  
  #
  #  選局に必要な物理チャンネル名を生成
  #
  def makePhCh( data )
    phch = case data[:band]
           when Const::GR then data[:stinfo_tp].to_s
           when Const::CS then data[:stinfo_tp].to_s
           when Const::BS then sprintf("%s_%s",data[:stinfo_tp], data[:stinfo_slot] )
           end
    return phch
  end
  module_function :makePhCh

  #
  #  文字列からハッシュキー(数値)を生成
  #
  def makeHashKey( str )
    require 'digest/md5'
    digest = Digest::MD5.new
    digest.update( str )
    r = digest.hexdigest.hex % ( 2 ** 32 )
    return r
  end
  module_function :makeHashKey
  
  #
  #  時短に重畳した時間制限を分離
  #
  def jitanSep( jitan )
    jitan2 = jitan  & 0b0011
    timeLimitF = ( jitan & 0b1100 ) >> 2
    timeLimitV = ( jitan & 0xfff0 ) >> 4
    return [ jitan2, timeLimitF, timeLimitV ]
  end
  module_function :jitanSep

  #
  #  Unix秒 -> XXXX年/YY月/ZZ日
  #
  def int2date( time )
    Time.at( time ).strftime("%Y/%m/%d")
  end
  module_function :int2date

  #
  #  Unix秒 -> 10:10
  #
  def int2hm( time )
    Time.at( time ).strftime("%H:%M")
  end
  module_function :int2hm

  #
  #  x秒 -> y時z分
  #
  def duration( time )
    h = (time / 3600).to_i
    m = ( time - h * 3600 ) / 60
    if h > 0
      return "#{h}時間 #{m}分"
    else
      return "#{m}分"
    end
  end
  module_function :duration

  #
  #  開始、終了  ->  [ "2019/03/27", "08:00 〜 10:25 (2時間 25分)" ]
  #
  def stet_to_s( st, et )
    startD = int2date( st )
    startH = int2hm( st )
    fin    = int2hm( et )
    dra    = duration( et - st )
    wd = ["日", "月", "火", "水", "木", "金", "土"]
    wday   = wd[Time.at( st ).wday]

    return [ "#{startD}(#{wday})", "#{startH} 〜 #{fin}", "(#{dra})" ]
  end
  module_function :stet_to_s


  def printTR( rid, cl, *arg )
    cls = ""
    cls = "class=\"" + cl.join(" ") + "\"" if cl != nil
    rids = ""
    rids = "rid=\"#{rid}\"" if rid != nil
    a = [ %Q{ <tr> } ]
    arg.each do |tmp|
      a << %Q{ <td #{cls} #{rids}> #{tmp} </td>}
    end
    a << %Q{ </tr> }
    a.join("\n")
  end
  module_function :printTR


  def printTR2( data, rid: nil, trcl: nil, tdcl: nil, id: nil, tdclf: nil )
    trcls  = trcl  != nil ? "class=\"" + trcl.join(" ") + "\"" : ""
    tdcls  = tdcl  != nil ? "class=\"" + tdcl.join(" ") + "\"" : ""
    rids = rid != nil ? "rid=\"#{rid}\""  :  ""
    ids  = id  != nil ? "id=\"#{id}\"" : ""

    a = [ %Q{ <tr #{ids} #{trcls}> } ]
    n = 1
    data.each do |tmp|
      if tdclf == nil or n > tdclf
        a << %Q{ <td #{tdcls} #{rids}> #{tmp} </td>}
      else
        a << %Q{ <td #{rids}> #{tmp} </td>}
      end
      n += 1
    end
    a << %Q{ </tr> }
    a.join("\n")
  end
  module_function :printTR2


  def print_hidden( id: nil, name: nil, val: nil )
    id2 = id != nil ? %Q( id="#{id}" ) : ""
    r = %Q(<input type="hidden" #{id2} name="#{name}" value="#{val}">)
  end
  module_function :print_hidden


  def datalist_dir()
    dirs = []
    Dir.open( TSDir ).sort.each do |dir|
      next if dir == "." or dir == ".."
      if test(?d, TSDir + "/" + dir )
        dirs << sprintf("           <option value=\"%s\">",dir)
      end
    end
    dirs.join("\n")
  end
  module_function :datalist_dir


  def makeTSfname( subdir, fname )
    path = TSDir + "/"
    if subdir != nil and subdir != ""
      subdir2 = normStr( subdir )
      path += subdir2.sub(/^\//,'').sub(/\/$/,'').strip + "/"
    end
    path += fname
  end
  module_function :makeTSfname


  def normStr( str )
    fn = str.dup
    fn.gsub!(/\//,'／')
    fn.gsub!(/　/,' ')
    fn.gsub!(/♯/,"#")
    fn.gsub!(/＃/,"#")
    fn.gsub!(/－/,'-')
    fn.gsub!(/〜/,'～')
    fn.tr!( 'ａ-ｚＡ-Ｚ！','a-zA-Z!')
    fn.tr!( '０-９','0-9')
    fn.gsub!(/\s+/,' ')
    return fn
  end
  module_function :normStr


  def include( fn )
    r = ""
    if test(?f, fn )
      File.open( fn, "r") do |fp|
        r = fp.read()
      end
    else
      DBlog::sto("file not found #{fn}")
    end
    r
  end
  module_function :include

  #
  #  条件付き include
  #
  def includeIf( sw, fn )
    r = ""
    return r if sw != true
    if test(?f, fn )
      File.open( fn, "r") do |fp|
        r = fp.read()
      end
    else
      DBlog::sto("file not found #{fn}")
    end
    r
  end
  module_function :includeIf


  #
  #  番組表に現在時の線を引く
  #
  def nowLine( st, tate, hour_pixel, stationN, stationW, offset = 0 )

    now = Time.now
    unless now.between?( st, st + tate * 3600 )
      return ""
    end

    y = tate * hour_pixel
    t =  ( now - st ) / 3600 * hour_pixel + offset
    top = -1 * ( y - t ).to_i
    w = stationN * stationW
    str1 = <<EOS
    <style type="text/css">
      .nowLine {
         display: block;
         position: relative;
         width: #{w}px;
         top: #{top}px;
         left: 3em;
         float:left;
         border-width: 2px 0 0 0; /* 太さ */
         border-style: solid;     /* 種類 */
         border-color: coral;       /* 色   */
         z-index: 10;
         margin:   0px 0px 0px 0px;
       }
    </style>
    <div class="row">
      <hr class="nowLine" />
    </div>
EOS
    str1
  end

  module_function :nowLine


  def statAna( t, clasS, bg )
    stat = nil
    recf = 0
    come = (t[:comment] != nil and t[:comment] != "") ? t[:comment] : nil
    case t[:stat]
    when RsvConst::Normal,RsvConst::NormalEnd then
      stat =  "○"
      stat += "(時短)" if t[:jitanExe] == RsvConst::JitanEOn
    when RsvConst::Conflict then
      stat =  "×"
      stat += " (#{come})" if come != nil
      clasS << "alertR"
    when RsvConst::RecNow then
      stat =  "録画中"
      recf = 1
    when RsvConst::AbNormalEnd then
      stat =  "×"
      stat += " (#{come})" if come != nil
      clasS << "alertR"
    when RsvConst::RecStop,RsvConst::RecStop2 then
      stat =  "中止"
      stat += " (#{come})" if come != nil
    when RsvConst::NotUse then
      stat =  "無効"
      stat += " (#{come})" if come != nil
      bg = %Q(colorGray)
    end

    [ stat, clasS, bg, recf ]
  end

  module_function :statAna

end
