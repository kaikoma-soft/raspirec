#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'sqlite3'

class DBaccess

  attr_reader :db
  
  def initialize( dbFname = DbFname )
    @db = nil
    @DBfile = dbFname
    @DBLockfile = dbFname + ".flock"
    unless File.exist?(@DBfile )
      open() do |db|
        db.transaction do
          createDB()
        end
      end
      File.chmod( 0600, @DBfile )
    end
  end

  def open
    File.open(@DBLockfile, File::RDWR|File::CREAT, 0644) do |fl|
      fl.flock(File::LOCK_EX)
      @db = SQLite3::Database.new( @DBfile )
      @db.busy_timeout(1000)
      ecount = 0
      begin
        yield self
      rescue SQLite3::BusyException
        STDERR.print ">SQLite3::BusyException #{ecount}\n"
        STDERR.flush()
        if ecount > 10
          STDERR.print ">SQLite3::BusyException exit\n"
          raise
        end
        ecount += 1
        sleep( rand(1.0..3.0) )
        retry
      rescue => e
        p $!
        puts e.backtrace.first + ": #{e.message} (#{e.class})"
        e.backtrace[1..-1].each { |m| puts "\tfrom #{m}" }
        ecount += 1
        if ecount > 10
          STDERR.print ">SQLite3::BusyException exit\n"
          raise
        end
        sleep( rand(1.0..3.0) )
        retry
      end
      close()
    end
  end
  
  def close
    if @db != nil
      @db.close()
      @db = nil
    end
  end

  def execute( *args )
    @db.execute( *args )
  end

  def transaction()
    @db.transaction do
      yield
    end
  end

  def prepare( str )
    @db.prepare( str )
  end
  
  #
  #  データがあるか
  #
  def getDB( fname )
    sql = "select * from data where fname = ?;"
    @db.execute( sql, fname ) do |row|
      return row
    end
    return nil
  end


  def getDBbyNmaeLike( *names )
    q = ""
    names.each do |name|
      q += "%#{name}%"
    end
    sql = "select DISTINCT * from data where fname like '#{q}' order by fname;"
    return @db.execute( sql )
  end

end
