#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  予約一覧 詳細ダイアログ
#


class ReservationListD

  def initialize( )
  end

  def getData( id )
    DBaccess.new().open do |db|
      programs = DBprograms.new()
      reserve = DBreserve.new
      data = reserve.select( db, id: id )
      if data.size > 0
        t1 = data.first
        t2 = programs.selectSP( db, evid: t1[:evid], chid: t1[:chid] )
        t3 = t2.first
        if t3 != nil
          t3.each_pair do |k,v|
            t1[k] = v
          end
        end
        return t1
      end
    end
    nil
  end

  
  
  def switch( name, init = 0, onoff = nil )
    on  = "On"
    off = "Off"
    if onoff != nil
      on  = onoff[0]
      off = onoff[1]
    end
      
    str = <<EOS
  <!-- Switch -->
  <div class="switch">
    <label>
      #{off}
      <input type="checkbox" name="#{name}">
      <span class="lever"></span>
      #{on}
    </label>
  </div>
EOS
    str
  end

  def checkbox( name, comment, val )
    checked = ""
    if val == 1
      checked = "checked=\"checked\""
    end
    str = <<EOS
      <label>
        <input type="checkbox" class="filled-in" name="#{name}" #{checked}/>
        <span>#{comment}</span>
      </label>
EOS
    str
  end

  def inputText( name, comment: "", val: "", size: 60, dlist: nil )
    dl = ""
    if dlist != nil and dlist.class == Array
      tmp = []
      tmp << %q(   <datalist id="dlist"> )
      tmp <<  dlist.map{|item| sprintf("  <option value=\"%s\">",item) }
      tmp << %q(  </datalist> )
      dl = tmp.join("\n")
    end

    str = <<EOS
        #{comment}
        <div class="input-field inline">
            <input id="email_inline" type="text" list="dlist" name="#{name}" size="#{size}" class="validate" value="#{val}" autocomplete="off">
            #{dl}
        </div>
EOS
    str
  end
  
  def printTable( rid )
    if ( t = getData( rid )) != nil
      printTable2( [t,nil] )
    end
  end

  
  #
  #  自動録画用のオプション項目の出力
  #
  def printOpt( dp, use_use: true )

    dirs = Commlib::datalist_dir()

    chk = %q(checked="checked")
    jitanchk = dp[:jitan] == 0 ? chk :  ""
    usechk   = dp[:stat] == RsvConst::NotUse ? chk :  ""
    subdir = dp[:subdir] 
      
    str1 = <<EOS
         <div class="input-field inline">
         保存サブディレクトリ
         <input id="email_inline" type="text" list="dlist" name="dir" size="40" class="validate" value="#{subdir}" autocomplete="off">
         <datalist id="dlist"> 
           #{dirs}
         </datalist> 
       </div>
       <br>
       <label>
         <input type="checkbox" class="filled-in" name="jitan" #{jitanchk}/>
         <span>チューナーが競合した場合に録画時間の短縮を許可する。</span>
       </label>
EOS
    str2 = <<EOS
       <br>
       <label>
         <input type="checkbox" class="filled-in" name="use" #{usechk}/>
         <span>この予約を無効とする。</span>
       </label>
EOS
    if use_use != true
      return str1 
    else
      return str1 + str2
    end
  end
  
  #
  #  データの表示
  #
  def printTable2( data, use_use = true )
    r = []
    t = data[0]
    t[:date] = Commlib::stet_to_s( t[:start], t[:end] ).join(" ")

    opt = printOpt( t, use_use: use_use )
    name = t[:name] == nil ? "" : t[:name]
    detail = t[:detail] == nil ? "" : t[:detail]
    
    [["放送局名",  name + "  " + "(#{t[:chid]})" ],
     ["番組名",    t[:title] + "  " + "(evid=#{t[:evid]})" ],
     ["内容",      detail ],
     ["録画時間",  t[:date] ],
     ["種別",      t[:type] == 0 ? "手動予約" : "自動予約"],
     ["オプション", opt ],
    ].each do |tmp|
      r << printTable3(tmp[0], tmp[1])
    end

    if t[:stat] == RsvConst::RecNow
      r << Commlib::print_hidden( id: "recFlag", name: "RecNow", val: "1" )
    end
    r.join("\n")
  end

  def printTable3( title, val)
    sprintf(%Q{<tr> <th class="nowrap" > %s </th><td> %s </td>},title, val)
  end

end

if File.basename($0) == "rsv_list_D.rb"

  [ ".", ".." ].each do |dir|
    if test(?f,dir + "/require.rb")
      $: << dir
    end
  end
  require 'require.rb'

  rt = ReservationListD.new()
  rt.printTable( 4 )

  exit

  case ARGV[0]
  when "1"
    puts( rt.printTable( 1 ) )
  end

end
