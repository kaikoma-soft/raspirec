#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  予約一覧
#
require 'sys/filesystem'

class Control

  def initialize( )

  end

  #
  #   ログファイルのローテート
  #
  def logrote()
    lr = LogRote.new()
    DBlog::sto( "Log rotate" )
    lr.exec()
  end

  #
  #  file 転送
  #
  def fcopy( params )
    Thread.new do
      fname = params[ "fname" ]
      from = TSDir + "/" + fname
      return unless test( ?f, from )
    
      subdir = File.dirname( fname )
      errmsg = nil
      fc = FileCopy.new
      ( speed, errmsg )  = fc.scp( TSFT_toDir, subdir, from )

      if errmsg == nil
        tmp = sprintf("手動転送終了: %s (%.1f Mbyte/sec)", fname, speed )
      else
        tmp = sprintf("手動転送失敗: %s : %s",errmsg , fname )
      end
      DBaccess.new().open() do |db|
        DBlog::info(db,tmp)
      end
    end
  end
    
  def tsft( arg )               #  "true" で不許可
    DBaccess.new().open( tran: true ) do |db|
      DBkeyval.new.upsert( db, "tsft", arg )
      if arg != "true"
        DBupdateChk.new.touch()
      end
    end
  end
  
  def logdel( arg )
    DBaccess.new().open( tran: true ) do |db|
      sql = "delete from log "
      if arg != "all"
        n = arg.to_i
        if n > 0
          time = Time.now.to_i - n * 3600 * 24 
          sql += " where time < #{time} ;"
        end
      end
      db.execute( sql )
    end
  end
  
  def epg()
    phchid = DBphchid.new
    t = Time.now.to_i - ( 3600 * 24 )
    DBaccess.new().open( tran: true ) do |db|
      row = phchid.select( db )
      row.each do |r|
        phchid.touch( db, t, phch: r[:phch] )
      end
    end
    DBupdateChk.new.touch()
  end
  
  def filupd( )
    FilterM.new.update()
  end
  
  def sendSignal( fname, signal = :HUP )
    if test( ?f, fname )
      File.open( fname,"r" ) do |fp|
        pid = fp.gets().to_i
        if pid > 0
          begin
            Process.kill( signal, pid )
          rescue Errno::ESRCH
          end
        end
      end
    end
  end

  def restart( )
    [ TimerPidFile, HttpdPidFile ].each do |fname|
      sendSignal( fname, :HUP )
    end
  end
  
  def stop( )
    if test( ?f, PidFile )
      File.open( PidFile,"r" ) do |fp|
        pid = fp.gets().to_i
        if pid > 0
          begin
            Process.kill( :TERM, pid )
          rescue Errno::ESRCH
          end
        end
      end
    end
  end

end

