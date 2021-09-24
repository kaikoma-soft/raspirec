#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  EPG の json を読みやすく整形して出力する。
#

require 'optparse'
require 'fileutils'
require 'json'


class Json2text

  PRO   = "programs"
  TITLE = "title"
  EVID  = "event_id"
  CHAN  = "channel"
  DETA  = "detail"
  EXTD  = "extdetail"
  START = "start"
  ENDT  = "end"
  DURA  = "duration"
  CATE  = "category"
  STINF = "satelliteinfo"
  
  def initialize( fname, opt )
    @count = 0
    
    File.open( fname, "r" ) do |fp|
      str = fp.read
      data = JSON.parse(str)
      if opt[:evid] != nil
        evid = opt[:evid].to_i
        data.each do |ch|
          if ch[ PRO ] != nil
            ch[ PRO ].each do |prog|
              if prog[ EVID ] == evid
                print( ch, prog )
              end
            end
          end
        end
      else
        data.each do |ch|
          if ch[ PRO ] != nil
            ch[ PRO ].each do |prog|
              print( ch, prog )
            end
          end
        end
      end
    end
  end


  def print( ch, prog)
    puts("") if @count > 0
    
    name = ch["name"]
    stinf = ch[STINF] != nil ?
              sprintf("%s_%s",ch[STINF]["TP"],ch[STINF]["SLOT"]) :
              ""
    [ CHAN, TITLE, DETA,EVID, START, ENDT, DURA ].each do |key|
      case key
      when START, ENDT
        val = Time.at( prog[ key ] / 1000 ).to_s
      when CHAN
        val = sprintf("%s %s %s", name, prog[ key ], stinf )
      else
        val = prog[ key ]
      end
      printf("%10s: %s\n", key, val )
    end

    @count += 1
  end
  
end


$opt = {
  :evid => nil,                 # event id 指定
}

OptionParser.new do |opt|
  opt.on('--evid  ID') {|v| $opt[:evid] = v }
  opt.parse!(ARGV)
end


ARGV.each do |fname|
  Json2text.new( fname, $opt )
end

