#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
# 地デジ チャンネルスキャン
#

require 'optparse'
require 'json'

base = File.dirname( $0 )
[ ".", "..","src", base + "/..", ].each do |dir|
  if test( ?f, dir + "/require.rb")
    $: << dir
  end
end
require 'require.rb'


$opt = {
  :d         => false,          # debug 
  :w         => false,          # write config
  :t         => 10,             # scan time
}

OptionParser.new do |opt|
  opt.on('-d')     { $opt[:d] = true }
  opt.on('-w')     { $opt[:w] = true }
  opt.on('-t n')   {|v| $opt[:t] = v.to_i }
  opt.parse!(ARGV)
end


class ExecError < StandardError; end


GR_start = 10
GR_end   = 52
pt1 = Recpt1.new
$rec_pid = []

outdir = DataDir + "/json"
unless test(?d, outdir )
  Dir.mkdir( outdir )
end

r = []
GR_start.upto(GR_end) do |ch|
  outfname = outdir + "/#{ch}.json"
  now1 = Time.now
  cn = pt1.getEpgJson_retry( ch, $opt[:t], outfname )
  now2 = Time.now

  name = ""
  id = ""
  if test( ?s, outfname )
    File.open( outfname, "r" ) do |fp|
      str = fp.read
      data = JSON.parse(str)
      if data.size > 0
        data.each do |d|
          name += d["name"] + " "
          id   += d["id"] + " "
        end
      end
    end
  end

  if $opt[:d] == true 
    printf("%02d : %03.1fdB  %s %s (%d)\n",ch, cn, id, name, now2 - now1  )
  else
    printf("%02d : %03.1fdB  %s %s\n",ch, cn, id, name )
  end
  if name != ""
    r << sprintf("%d \t# %s %s\n",ch, id, name)
  end

  sleep(0.1)
end

