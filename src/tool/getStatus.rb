#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  録画サーバーが指定した時間に稼働中か判定する。
#      0      -> wait
#      0以外  -> busy

require 'optparse'

base = File.dirname( $0 )
[ ".", "..","src", base + "/..", ].each do |dir|
  if test(?f,dir + "/require.rb")
    $: << dir
  end
end
require 'require.rb'

#
#  引数の解析
#
$opt = {
  :t    =>    600,              # チェックする時間
}

OptionParser.new do |opt|
  opt.on('-t n')     {|v| $opt[ :t ] = v.to_i } 
  opt.parse!(ARGV)
end

if EpgLock::lock?() == false
  timer = Timer.new
  ( queue, recCount, nextRecTime ) = timer.getNextProg()

  sa = nextRecTime - Time.now.to_i
  if recCount > 0 or  sa < $opt[:t]
    exit -1
  end
else
  exit -1
end

exit 0


  
