#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'sqlite3'

class DBaccess

  attr_reader :db
  
  def initialize( dbFname = DbFname )
    @db = nil
    @DBfile = dbFname
    unless File.exist?(@DBfile )
      open( tran: true ) do |db|
        createDB()
      end
      File.chmod( 0600, @DBfile )
    end
  end

  def open( tran: false, mode: :deferred )       # tran = true transaction
    
    #puts caller[0][/`.*'/][1..-2]
    @db = SQLite3::Database.new( @DBfile )
    @db.busy_timeout(1000)
    ecount = 0
    begin
      if tran == true
        @db.transaction( mode ) do
          yield self
        end
      else
        yield self
      end
    rescue SQLite3::BusyException => e
      DBlog::sto("SQLite3::BusyException tran = #{tran.to_s} #{ecount}")
      begin
        @db.rollback() if tran == true
      rescue
        #DBlog::sto("rollback fail #{$!}")
      end
      if ecount > 20
        DBlog::sto("SQLite3::BusyException exit")
        DBlog::sto( $! )
        DBlog::sto( e.backtrace.first + ": #{e.message} (#{e.class})" )
        e.backtrace[1..-1].each { |m| DBlog::sto("\tfrom #{m}") }
        return
      end
      @db.rollback
      ecount += 1
      sleep( 1 )
      retry
    rescue => e
      DBlog::sto("SQLite3::another error")
      DBlog::sto( $! )
      DBlog::sto( e.backtrace.first + ": #{e.message} (#{e.class})")
      e.backtrace[1..-1].each { |m| DBlog::sto("\tfrom #{m}") }
      begin
        @db.rollback() if tran == true
      rescue
        #DBlog::sto("rollback fail #{$!}")
      end
      return
    ensure
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

  #def transaction( mode = :immediate ) # :deferred or :immediate
  #  @db.transaction( mode ) do
  #    yield
  #  end
  #end

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
