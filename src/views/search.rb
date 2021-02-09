#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  番組検索
#

class Search

  def initialize( )

  end

  def dirList()
    Commlib::datalist_dir()
  end
  
  def p_hidden( id )
    if id != nil
      r = %Q(<input type="hidden" name="id" value="#{id}">)
    end
    r
  end

  def defaltData()
    data = { title1:  "",
             key:     "",
             exclude: "",
             stype:   { simple: true, regex: false },
             target:  { title:  true, titleP: false },
             band:    { gr: true, bs: true, cs: true },
             cate:    "0",
             chanel:  "0",
             subdir:  "",
             jitan:    D_jitan,
             freeOnly: D_FreeOnly,
             dedupe:   D_dedupe,
             jikan:   { none: true, up: false, down: false, val: 0 },
           }
    # 0.upto( 6 ) do |n|
    #   data[ "wday#{n}".to_sym ] = true
    # end

    data
  end

  #
  #  不必要な文字を削除
  #
  def delNeedless( regex, str )
    str2 = str.dup
    regex.each do |pat|
      str2.gsub!(pat,'')
    end
    str2.sub!(/　$/,'')
    str2.sub!(/^　/,'')
    return str2.strip
  end

  #
  #  番組情報のカテゴリから小項目を削る。(全てにする)
  #
  def cateSubZero( cate )
    ret = {}
    cate.each do |tmp|
      tmp2 = tmp.sub(/(\d+)-(\d+)/,'\1-0')
      ret[ tmp2 ] = 1
    end
    return ret.keys.sort
  end
    
  #
  #  form の設定値を決定
  #
  def getData( proid: nil, filid: nil )
    if proid != nil             # 新規
      data = defaltData()
      DBaccess.new().open do |db|
        programs = DBprograms.new
        row = programs.select( db, id: proid )
        if row != nil
          t1 = delNeedless( ::TitleRegex, row[0][:title])
          t2 = delNeedless( ::SearchStringRegex, row[0][:title])
          data[:title1] = t1
          data[:key]    = t2
          data[:chanel] = row[0][:chid]
          tmp = []
          [ :categoryT1, :categoryT2, :categoryT3 ].each do |sym|
            tmp << row[0][sym] if row[0][sym] != nil
          end
          data[:cate] = cateSubZero( tmp ).join(" ")
        end
      end
    elsif filid != nil          # 変更
      DBaccess.new().open do |db|
        filter = DBfilter.new()
        d = filter.select( db, id: filid ).first
        stype = d[:regex] == FilConst::RegexOff ? true : false
        target = d[:target] == FilConst::TargetT ? true : false
        band = {}
        [ :gr, :bs, :cs ].each_with_index do |b,n|
          band[ b ] = false
          band[ b ] = true if d[:band][ n ] == 1
        end

        ( jitan, timeLimitF, timeLimitV ) = Commlib::jitanSep( d[:jitan] )
                
        data = { title1:  d[:title],
                 key:     d[:key],
                 exclude: d[:exclude],
                 stype:   { simple: stype, regex: !stype },
                 target:  { title:  target, titleP: !target },
                 band:    band,
                 cate:    d[:category],
                 chanel:  d[:chanel],
                 jitan:   jitan == RsvConst::JitanOn ? true : false,
                 subdir:  d[:subdir] != nil ? d[:subdir].strip : "",
                 freeOnly: d[:freeOnly] == RsvConst::FO ? true : false,
                 dedupe:   d[:dedupe] == RsvConst::Dedupe ? true : false,
                 jikan:   { none: false, up: false, down: false, val: 0 },
               }
        case timeLimitF
        when 0 then data[:jikan][:none] = true
        when 1 then data[:jikan][:up] = true
        when 2 then data[:jikan][:down] = true
        end
        data[:jikan][:val] = timeLimitV
        
      end
    else                        # 新規作成時のデフォルト値
      data = defaltData()
    end

    data
  end

  #
  #  チャンネル選択 select文の生成
  #
  def p_ch_sel( dp )
    a = []
    nameH = {}
    chanels = {}
    dp[:chanel].split.each {|v| chanels[v] = true }
    
    a << %q(<select multiple name="ch[]" class="mselect">)
    sel = chanels["0"] == true ? "selected" : ""
    a << %Q(    <option id="op" value="0" #{sel} > 全て </option>)
    DBaccess.new().open do |db|
      chan = DBchannel.new()
      cd = chan.select( db )
      band = nil
      cd.sort do |a,b|
        if a[:band_sort] != b[:band_sort]
          a[:band_sort] <=> b[:band_sort]
        else
          a[:name] <=> b[:name]
        end
      end.each do |ch|
        next if ch[:updatetime] == -1
        if ch[:band ] != band
          band2 = ch[:band] == "GR" ? Const::GRJ : ch[:band]
          a << %Q(    <optgroup label="#{band2}">)
          band = ch[:band]
        end
        name2 = ch[:name]
        if nameH[ name2 ] != nil
          name2 += "(#{ch[:svid]})"
        end
        nameH[ name2 ] = true
        sel = chanels[ ch[:chid] ] == true ? "selected" : ""
        a << %Q(    <option id="op" value="#{ch[:chid]}" #{sel}> #{name2} </option>)
      end
    end
    a << %q(</select>)
    a.join("\n")
  end

  #
  #  カテゴリ選択
  #
  def p_cate_sel( dp )
    sel = dp[:cate]
    selC = {}
    sel.split().each do |tmp|
      if tmp =~ /(\d+)\-(\d+)/
        selC[tmp] = true
      end
    end
    
    cateM = {}
    category = DBcategory.new()
    a = []
    a << %q(<select multiple name="cate[]">)
    sel2 = sel == "0" ? "selected" : ""
    a << %Q(    <option id="op" value="0" #{sel2} > 全て </option>)
    DBaccess.new().open do |db|
      cd = category.selectL( db )
      cd.each do |ct|
        cateM[ ct[:id] ] = ct[:name]
        a << %Q(    <optgroup label="#{ct[:name]}">)

        pid = ct[:id]
        sel2 = selC["#{pid}-0"] == true ? "selected" : ""
        a << %Q(    <option  value="#{pid}-0" #{sel2}> #{ct[:name]}@全て </option>)

        cm = category.selectM( db, pid: pid )
        cm.each do |cm2|
          next if cm2[:name] == nil or cm2[:name] == ""
          val = "#{pid}-#{cm2[:id]}"
          sel2 = selC[ val ] == true ? "selected" : ""
          a << %Q(    <option value="#{val}" #{sel2}> #{ct[:name]}@#{cm2[:name]} </option>)
        end
      end
      a << %q(</select>)
    end
    a.join("\n")
  end
  
  #
  #  カテゴリ選択 select文の生成 その1
  #
  def p_cate_sel1_old( dp )

    sel = dp[:cate]
    selM = sel.sub(/-\d+/,'').to_i
    cateM = {}
    category = DBcategory.new()
    a = []
    a << %q(<select class="parent browser-default" name="cateM">)
    sel2 = sel == "0" ? "selected" : ""
    a << %Q(    <option id="op" value="0" #{sel2} > 全て </option>)
    DBaccess.new().open do |db|
      cd = category.selectL( db )
      cd.each do |ct|
        cateM[ ct[:id] ] = ct[:name]
        sel2 = selM == ct[:id] ? "selected" : ""
        a << %Q(    <option value="#{ct[:id]}" #{sel2}> #{ct[:name]} </option>)
      end
      a << %q(</select>)
      a << %q(</div>)
      a << %q(<div class="col">)
      dis = sel == "0" ? "disabled" : ""
      a << %Q(<select class="children browser-default" name="cateS" #{dis} >)
      cateM.each_pair do |pid,name|
        cd = category.selectM( db, )
        sel2 = sel == "#{pid}-0" ? "selected" : ""
        a << %Q(    <option  data-val="#{pid}" value="#{pid}-0" #{sel2}> 全て </option>)
        cd.each do |ct|
          val = "#{pid}-#{ct[:id]}"
          sel2 = sel ==  val ? "selected" : ""
          a << %Q(    <option  data-val="#{pid}" value="#{val}" #{sel2}> #{ct[:name]} </option>)
        end
      end
      a << %q(</select>)
    end
    
    a.join("\n")
  end


  
end


