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

  def parse_caller(at)
    if /^(.+?):(\d+)(?::in `(.*)')?/ =~ at
      file = File.basename( $1 )
      line = $2.to_i
      method = $3
      return sprintf( "DB_caller : %s %d %s", file, line, method )
    end
    ""
  end
  
  #
  #  DB open  mode = :immediate or :deferred or :exclusive
  # 
  def open( tran: false, mode: :immediate )       # tran = true transaction
    #DBlog::stoD( parse_caller( caller.first ) ) if $debug == true
    @db = SQLite3::Database.new( @DBfile )
    @db.busy_timeout(1000)
    ecount = 0
    roll = false
    begin
      roll = false
      if tran == true
        @db.transaction( mode ) do
          roll = true
          yield self
        end
      else
        yield self
      end
    rescue SQLite3::BusyException => e
      DBlog::sto("SQLite3::BusyException tran = #{tran.to_s} #{ecount}")
      begin
        @db.rollback() if roll == true
      rescue
        DBlog::sto("rollback fail #{$!}")
      end
      if ecount > 59
        Commlib::errPrint( "SQLite3::BusyException exit", $!, e )
        return
      else
        #Commlib::errPrint( "SQLite3::BusyException retry", $!, e )
        ecount += 1
        sleep( 1 )
        DBlog::sto("retry")
        retry
      end
    rescue => e
      Commlib::errPrint( "SQLite3::another error", $!, e )
      begin
        @db.rollback() if roll == true
      rescue
        DBlog::sto("rollback fail #{$!}")
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
