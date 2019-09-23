#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  予約一覧
#
require 'sys/filesystem'

class Control

  def initialize( )

  end

  def fcopy( params )
    Thread.new do
      fname = params[ "fname" ]
      from = TSDir + "/" + fname
      return unless test( ?f, from )
    
      subdir = File.dirname( fname )
      errmsg = nil
      fc = FileCopy.new
      #( speed, errmsg )  = fc.ssh_nc( TSFT_toDir, subdir, from )
      ( speed, errmsg )  = fc.scp( TSFT_toDir, subdir, from )

      if errmsg == nil
        tmp = sprintf("手動転送終了: %s (%.1f Mbyte/sec)", fname, speed )
      else
        tmp = sprintf("手動転送失敗: %s : %s",errmsg , fname )
      end
      DBaccess.new().open do |db|
        db.transaction do
          DBlog::info(db,tmp)
        end
      end
    end
  end
    
  def tsft( arg )               #  "true" で不許可
    DBaccess.new().open do |db|
      db.transaction do
        DBkeyval.new.upsert( db, "tsft", arg )
        if arg != "true"
          DBupdateChk.new.touch()
        end
      end
    end
  end
  
  def logdel( arg )
    DBaccess.new().open do |db|
      db.transaction do
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
  end
  
  def epg()
    phchid = DBphchid.new
    t = Time.now.to_i - ( 3600 * 24 )
    DBaccess.new().open do |db|
      db.transaction do
        row = phchid.select( db )
        row.each do |r|
          phchid.touch( db, t, phch: r[:phch] )
        end
      end
    end
    DBupdateChk.new.touch()
  end
  
  def filupd( )
    FilterM.new.update()
  end
  
  def restart( )
    [ TimerPidFile, HttpdPidFile ].each do |fname|
      if test( ?f, fname )
        File.open( fname,"r" ) do |fp|
          pid = fp.gets().to_i
          if pid > 0
            Process.kill( :HUP, pid )
          end
        end
      end
    end
  end
  
  def stop( )
    if test( ?f, PidFile )
      File.open( PidFile,"r" ) do |fp|
        pid = fp.gets().to_i
        if pid > 0
          Process.kill( :TERM, pid )
        end
      end
    end
  end

end

