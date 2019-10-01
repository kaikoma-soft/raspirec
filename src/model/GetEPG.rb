#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  EPG 取得
#
require 'timeout'

class GetEPG

  def initialize(  )
  end

  #
  #  json ファイルの読み込み
  #
  def readJson( fname, ch, band, fpw )

    unless test(?f, fname )
      fpw.close if fpw != nil
      return false
    end
    
    count = { :upd => 0, :ins => 0, :del => 0, :same => 0 }
    File.open( fname, "r" ) do |fp|
      str = fp.read
      data = JSON.parse(str)
      if data == nil or data.size == 0
        errorProc( ch )
        return false
      end

      channel  = DBchannel.new
      programs = DBprograms.new
      category = DBcategory.new
      phchid   = DBphchid.new

      DBaccess.new().open do |db|
        db.transaction do
          data.each do |d|
            ch2 = channel.select( db, chid: d["id"] )
            if ch2.size == 0
              data2 = channel.dataConv( d, ch )
              channel.insert( db, data2 )
              DBlog::debug(db,"add ch #{d["name"]}" )
              ch2 = channel.select( db, chid: d["id"] )
            end
            phchid.add(db, ch, d["id"], Time.now.to_i ) 
            
            datas = []
            d["programs"].each do |pro|
              cateId = category.conv2id(db, pro["category"] )
              pro2 = programs.dataConv( db, pro, ch2[0][:chid],cateId )
              r = programs.select( db, chid: pro2[:chid], evid: pro2[:evid] )
              if r.size == 0
                #programs.insert( db, data )
                next if pro2[:title] == nil or pro2[:title] == ""
                datas << pro2
                count[:ins] += 1
              elsif r.size == 1
                # 拡張情報は抜ける場合があるので補正
                if r[0][:extdetail] != "--- []\n"
                  pro2[:extdetail] == "--- []\n"
                  pro2[:extdetail] = r[0][:extdetail]
                end
                if programs.diff( r[0], pro2 ) == true
                  programs.update( db, r[0][:id], pro2 )
                  count[:upd] += 1
                else
                  count[:same] += 1
                end
              else
                fpw.close if fpw != nil
                raise
              end
            end
            if datas.size > 0
              programs.bulkinsert2( db, datas )
            end
          end
          str = sprintf("%-9s : ins=>%4d,upd=>%4d,same=>%4d",
                        "Ch=#{ch}",count[:ins],count[:upd],count[:same])
          DBlog::debug(db, str )
        end
      end
    end
    if fpw != nil
      fpw.puts("upd=#{count[:upd]}")
      fpw.puts("ins=#{count[:ins]}") 
      fpw.puts("same=#{count[:same]}")
      fpw.close
    end
  end

  #
  #   失敗時の処理
  #
  def errorProc( ch )
    DBaccess.new().open do |db|
      db.transaction do
        phchid   = DBphchid.new
        time = Time.now.to_i - ( EPGperiod * 3600 ) / 2 
        phchid.touch( db, time, phch: ch   )
        DBlog::debug(db,"Error: ch=#{ch} の EPG 取得に失敗しました" )
      end
    end
  end

  #
  #  EPG 取得開始
  #
  def start( timeLimit = 400 )
    DBlog::sto( "GetEPG::start(#{timeLimit})")
    start = Time.now
    channel = DBchannel.new
    programs = DBprograms.new
    phchid   = DBphchid.new

    count = { :upd => 0, :ins => 0, :del => 0, :same => 0 }

    fileUseF = false
    if $debug == true            # 空の場合は、有るものを読む
      DBaccess.new().open do |db|
        db.transaction do
          size = channel.select( db ).size
          if size == 0
            fileUseF = true
          end
        end
      end
    end

    #
    #  更新対象のch を抽出
    #
    chs = { Const::GR => {}, Const::BSCS => {} }
    chlist = {}
    nameList = []
    if fileUseF == false
      th = Time.now.to_i - ( EPGperiod * 3600 )
      DBaccess.new().open do |db|
        db.transaction do
          row = phchid.select(db)
          row.each do |r|
            phch = r[:phch]
            chlist[ phch ] = true
            if r[:updatetime] < th
              nameList << r[:chid]
              case r[:chid]
              when /^GR/ then
                time = GR_EpgRsvTime ; band = Const::GR
              when /^BS/ then
                time = BS_EpgRsvTime ; band = Const::BSCS
              when /^CS/ then
                time = CS_EpgRsvTime ; band = Const::BSCS
              end
              chs[band][ phch ] = time
            end
          end
        end
      end
    end

    if nameList.size > 0 and nameList.size < 3 
      DBlog::sto( %Q(old> #{nameList.join(" ")}))
    end

    if GR_tuner_num > 0
      GR_EPG_channel.each {|v| chs[ Const::GR ][v] = GR_EpgRsvTime if chlist[v] == nil }
    end
    if BSCS_tuner_num > 0
      BS_EPG_channel.each {|v| chs[Const::BSCS][v] = BS_EpgRsvTime if chlist[v] == nil}
      CS_EPG_channel.each {|v| chs[Const::BSCS][v] = CS_EpgRsvTime if chlist[v] == nil}
    end
    
    return false if chs[Const::GR].size == 0 and chs[Const::BSCS].size == 0

    DBaccess.new().open do |db|
      db.transaction do
        DBlog::debug( db,"EPG取得開始" )
        DBkeyval.new.upsert( db, StatConst::KeyName, StatConst::EPGget )
      end
    end

    pids = []
    [ Const::GR, Const::BSCS].each do |band|
      pids << Thread.new do
        recpt1 = Recpt1.new
        chs[band].each_pair do |ch, time|
          sa = time + ( Time.now - start ).to_i
          if sa > timeLimit
            DBlog::sto("time limit break: #{timeLimit} : #{sa}" )
            break
          end
          if $recCount > 0
            DBlog::sto("rec now GetEPG break" )
            break
          end
      
          outfname = JsonDir + "/#{ch}.json"
          outfname_tmp = outfname + ".tmp"
          if fileUseF == false or
            !test(?f, outfname ) or
            File.size( outfname ) < 100
            begin
              recpt1.getEpgJson( ch, time, outfname_tmp )
              if test( ?f, outfname_tmp ) and File.size( outfname_tmp ) > 100
                File.rename(outfname_tmp, outfname )
              else              # 失敗
                errorProc( ch )
                next
              end
            rescue
              puts $!
              puts $@
              errorProc( ch )
              next
            end
          end
          $mutex.synchronize {
            reader, writer = IO.pipe
            pid = fork do       # json の読み込みで、メモリが肥大する対策
              reader.close
              begin
                Timeout.timeout( 60 ) do
                  readJson( outfname, ch, band, writer )
                end
              rescue Timeout::Error
                pid2 = Process.pid
                DBlog::sto("readJson() time out kill #{pid2} #{ch}" )
                Process.kill(:KILL, pid2 );
              end
            end
            writer.close
            while message = reader.gets()
              if message =~ /(ins|upd|same)=(\d+)/
                type = $1
                n = $2.to_i
                count[type.to_sym] += n
              end
            end
            Process.waitpid( pid )
          }
        end
      end
    end
    pids.each {|t| t.join}


    #
    # ガーベージコレクション
    #
    DBaccess.new().open do |db|
      chs = channel.select( db )
    end

    chs.each do  |row|          # 時間が掛かるので、分割で、
      $mutex.synchronize do
        DBaccess.new().open do |db|
          db.transaction do
            count[:del] += programs.gc(db, row[:chid] )
          end
        end
      end
      sleep(0.3)
    end

    str = sprintf("ins=>%4d,upd=>%4d,del=>%4d,same=>%4d",
                  count[:ins],count[:upd],count[:del],count[:same] )

    DBaccess.new().open do |db|
      db.transaction do
        phchid_gc(db)
        DBlog::debug(db,"EPG取得終了 #{str}" )
        DBkeyval.new.upsert( db, StatConst::KeyName, StatConst::None )
      end
    end

    return true if count[:ins] > 0 or count[:upd] > 0
    false
  end

  def phchid_gc(db)
    phchid   = DBphchid.new
    phlist = {}
    ( GR_EPG_channel + BS_EPG_channel + CS_EPG_channel ).each do |v|
      phlist[ v ] = true
    end
    row = phchid.select( db )
    delList = {}
    row.each do |r|
      if phlist[ r[:phch] ] == nil
        delList[ r[:phch] ] = true
      end
    end
    delList.keys.each do |phch|
      DBlog::debug( db,"phchid_gc( #{phch})" )
      phchid.delete( db, phch )
    end
  end
  
end

