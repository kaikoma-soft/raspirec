#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-


#
#  一日一回
#

class Daily

  @@lastTime = nil              # 前回の実行時間
  
  def initialize( )
  end

  def run()
    keyval = DBkeyval.new
    key = "daily"

    if @@lastTime == nil
      DBaccess.new().open do |db|
        @@lastTime = keyval.select( db, key )
        if @@lastTime == nil
          @@lastTime = Time.now.to_i
          keyval.upsert(db, key, @@lastTime )
          return
        end
      end
    end

    threshold = (Time.now - ( 24 * 3600 )).to_i
    if @@lastTime < threshold
      
      #
      #   二重録画のチェック(デバック時のみ)
      #
      if $debug == true
        DBlog::sto("++++  二重録画のチェック  ++++")
        DBaccess.new().open( ) do |db|
          reserve = DBreserve.new
          reserve.dupRecChk( db )
        end
      end
      
      #
      #  古いデータの削除
      #
      DBaccess.new().open( tran: true ) do |db|
        DBlog::debug( db, "daily task start" )
        now = Time.now.to_i
        DBlog.new.deleteOld( db, now - LogSaveDay * 24 * 3600 )
        DBreserve.new.deleteOld( db, now - RsvHisSaveDay * 24 * 3600 )

        lr = LogRote.new()
        if lr.need?() == true
          DBlog::debug( db, "Log rotate" )
          sleep(1)
          lr.exec()
        end

        @@lastTime = Time.now.to_i 
        keyval.upsert(db, key, @@lastTime ) # 日付更新
      end

      #
      # DB ファイルのバックアップ
      #
      sleep(1)
      DBlog::vacuum()
      sleep(1)
      wday = Time.now.strftime("%a")
      fname = sprintf( "%s.backup-%s", DbFname ,wday )
      FileUtils.cp( DbFname, fname )
      DBlog::debug( nil, "DB file backup (#{fname})" )

      #
      # json ファイルの掃除
      #
      older = Time.now - ( ( EPGperiod + 1 ) * 3600 )
      Dir.open( JsonDir ).each do |file|
        next if file == "." or file == ".."
        if file =~ /\.(json|tmp)$/
          path = JsonDir + "/" + file
          if test( ?f, path )
            mtime = File.mtime( path )
            if mtime < older
              File.unlink( path )
            end
          end
        end
      end
    end
  end
end



if File.basename($0) == "Daily.rb"
  base = File.dirname( $0 )
  [ ".", "..","src", base ].each do |dir|
    if test( ?f, dir + "/require.rb")
      $: << dir
    end
  end
  require 'require.rb'

  Daily.new.run

end

