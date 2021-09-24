#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  複数のイベントが終わるのを待って、ある処理を行い、wait を終了する。
#

class MeetUpEvent

  @@list = {}
  @@mutex = Mutex.new
  
  def initialize( key, evid )
    @key = key
    @evid = evid
    @limit = 180                # 3分

    DBlog::stoD( "MeetUpEvent::init() #{@evid}" )
    @@mutex.synchronize do
      @@list[ key ] = [] if @@list[ key ] == nil or @@list[ key ] == :fin
      @@list[ key ].push( evid )
    end
  end

  #
  #  最後のまでまって処理 -> ループ開放
  #
  def wait()
    DBlog::stoD( "MeetUpEvent::wait() #{@evid}" )
    flag = false
    @@mutex.synchronize do
      if @@list[ @key ] != nil
        if @@list[ @key ].class == Array
          @@list[ @key ].delete( @evid )
          if @@list[ @key ].size == 0
            flag = true
          end
        end
      end
    end

    if flag == true
      DBlog::stoD( "MeetUpEvent::wait() #{@evid} proc start" )
      yield
      @@mutex.synchronize do
        @@list[ @key ] = :fin
      end
      DBlog::stoD( "MeetUpEvent::wait() #{@evid} proc end" )
    else
      count = 0
      while @@list[ @key ] != :fin
        sleep(1)
        count += 1
        if count > @limit
          DBlog::stoD( "MeetUpEvent::wait() break" )
          break
        end
      end
      DBlog::stoD( "MeetUpEvent::wait() fin" )
    end
  end


end

