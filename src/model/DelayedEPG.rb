# coding: utf-8

#
#  録画済みの TSファイルから、EPG データを採取する
#
#  ・32bit OS のRaspbian で 大きいファイルの最後に seek しようとすると失敗
#    するので、最初の 1Gbyte で。
#  ・それでも epgdump が coreダンプするものがあり、録画した TS から抽出
#    するのは無理か

class DelayedEPG
  
  def initialize( time_limit )

    @ts = Time.now
    phchid  = DBphchid.new
    reserve = DBreserve.new

    list = []
    chid2upt = {}               # chid 対 更新時間
    chid2phch = {}              # chid 対 phch

    DBaccess.new().open do |db|
      db.transaction do

        # EPG取得 の最終実施時間の取得
        ph = phchid.select(db)
        ph.each do |tmp|
          chid2upt[ tmp[:chid] ] = tmp[:updatetime]
          chid2phch[ tmp[:chid] ] = tmp[:phch]
        end
        #pp chid2upt

        # 最近の録画リスト取得
        order = "order by  end desc"
        row = reserve.select( db, stat: RsvConst::NormalEnd, order: order, limit: "10" )
        exist = {}                  # 重複
        row.each do |tmp|
          #pp "+ #{tmp[:title]} #{Time.at(tmp[:end]).to_s}"
          chid = tmp[:chid]
          et   = tmp[:end]
          if chid2upt[chid] < et
            #pp et - chid2upt[chid] 
            path = makePath( tmp )
            if test(?f, path )
              if exist[ chid ] == nil
                list << tmp
                exist[ chid ] = true
              end
            else
              pp "file not found #{path}"
            end
          end
        end
      end
    end

    return if list.size == 0

    ge = GetEPG.new
    count = { :upd => 0, :ins => 0, :del => 0, :same => 0 }

    list.reverse.each do |tmp|  # 処理は古い方から

      # 中断の判断
      if Time.now > time_limit
        DBlog::sto("DelayedEPG time limit: #{timeLimit}" )
        return
      end
      
      tspath = makePath( tmp )
      pp "#{tmp[:title]} #{tspath} #{tmp[:chid]}"
      json = JsonDir + "/#{tmp[:chid]}.json"
      phch = chid2phch[ tmp[:chid] ]
      next if phch == nil

      @ts = Time.now
      ppp("execEpgdump() start")
      execEpgdump( tspath, json )
      if test(?f, json ) and File.size( json ) > 100
        ge.readJsonProc( json, phch, count )
      else
        DBlog::sto( "json file error (#{json})" )
      end
      ppp("execEpgdump() end")
    end

    str = sprintf("ins=>%4d,upd=>%4d,same=>%4d",
                  count[:ins],count[:upd],count[:same] )
    DBlog::debug(nil, "delayed EPG取得終了 #{str}" )

  end

  def makePath( tmp )
    subd = tmp[:subdir] == "" ? "" : "/" + Commlib::normStr(tmp[:subdir])
    path = sprintf("%s%s/%s",TSDir, subd, Commlib::normStr(tmp[:fname]) )
  end

  def execEpgdump( tspath, json )
    bsize = 1024
    outbuf = "x" * bsize;
    cmd = [ Epgdump, "json", "-", json, :err=>[:child, :out]  ]
    limit = 1024 * 1024 * 1024  # 1Gbyte
    fsize = 0
    st = Time.now

    IO.popen( cmd, "r+" ) do |io|
      File.open( tspath, "r") do |fr|
        begin
          while fr.sysread( bsize, outbuf ) != nil
            io.write( outbuf )
            fsize += outbuf.size
            break if fsize > limit
            break if ( Time.now - st ) > 120 # 120秒で timeout
          end
        rescue EOFError => e
        rescue => e
          pp e
        end
        io.close_write
      end
    end
  end
  
end


if File.basename($0) == "DelayedEPG.rb"
  base = File.dirname( $0 )
  [ ".", "..","src", base ].each do |dir|
    if test( ?f, dir + "/require.rb")
      $: << dir
      $baseDir = dir
    end
  end

  require 'require.rb'

  phchid  = DBphchid.new
  DBaccess.new().open do |db|
    db.transaction do
      phchid.add(db, "BS15_0","BS_200", (Time.now - 3600 * 24 ).to_i )
    end
  end

  $debug = true
  
  DelayedEPG.new( Time.now + 600 )

  exit
  
end
