#!/usr/bin/ruby
# -*- coding: utf-8 -*-


class DBlog

  Stdout    = 0                 # level 0 標準出力のみ、記録しない
  Debug     = 1                 # level 1 デバック
  Info      = 2                 # level 2 情報
  Attention = 3                 # level 3 注意
  Warning   = 4                 # level 4 警告
  Error     = 5                 # level 5 エラー
  
  def initialize( )
    @list = {
      id:       "id",
      level:    "level",
      time:     "time",
      str:      "str",
    }
    @para = []
    @list.each_pair { |k,v| @para << v }
    @tbl_name = "log"
  end

  def self.vacuum(  )
    sql = "vacuum;"
    DBaccess.new().open do |db|
      db.execute( sql )
    end
  end
  

  def self.write( db, str, level )
    now = Time.now
    if level > 0
      sql = "insert into log (level,time,str) values (?,?,?);"
      if db == nil
        DBaccess.new().open do |db|
          db.execute( sql, level, now.to_i, str)
        end
      else
        db.execute( sql, level, now.to_i, str)
      end
    end
    txt = sprintf("%s: %s\n",now.strftime("%H:%M:%S"),str)
    File.open( LogFname, "a" ) do |fp|
      fp.puts( txt )
      fp.flush
    end
    #STDOUT.puts( txt )
    #STDOUT.flush
  end
  
  def self.sto( str )
    write( nil, str, Stdout )
  end
  
  def self.debug( db, str )
    write( db, str, Debug )
  end

  def self.info( db, str )
    write( db, str, Info )
  end

  def self.atte( db, str )
    write( db, str, Attention )
  end

  def self.warn( db, str )
    write( db, str, Warning )
  end
  
  def self.error(db, str )
    write( db, str, Error )
  end
  
  def self.puts( *args )
    if args.size == 3
      ( db, level, str ) = args
    elsif args.size == 2
      ( level, str ) = args
      db == nil
    elsif args.size == 1
      str = args.first
      level = Stdout
    else
      raise
    end

    now = Time.now
    if level > 0
      sql = "insert into log (level,time,str) values (?,?,?);"
      if db == nil
        DBaccess.new().open do |db|
          db.execute( sql, level, now.to_i, str)
        end
      else
        db.execute( sql, level, now.to_i, str)
      end
    end
    txt = sprintf("%s: %s\n",now.strftime("%H:%M:%S"),str)
    File.open( LogFname, "a" ) do |fp|
      fp.puts( txt )
    end
    STDOUT.puts( txt )
  end
  

  def select( db, level: nil, limit: nil )
    where = []
    args = []
    sql = "select * from log "
    if level != nil
      where << "level > ?"
      args << level
    end

    if where.size > 0
      sql += " where " + where.join(" and ")
    end
    sql += " order by id desc "

    if limit != nil 
      sql += limit
    end

    row = db.execute( sql, *args )
  end
  
  #
  #   カウント
  #
  def count( db, level: nil )
    sql = "select count( id ) from log "
    argv = []
    where = []
    if level != nil
      where << "level > ?"
      argv << level
    end

    if where.size > 0
      sql += " where " + where.join(" and ")
    end

    row = db.execute( sql, *argv )
    return row[0][0]
  end

  #
  #  削除
  #
  def deleteOld( db, time )
    sql = "delete from log where time < ? ;"
    db.execute( sql, time )
  end

  
end
