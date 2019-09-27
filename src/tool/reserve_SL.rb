#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#   予約関係データの save & load
#

require 'optparse'
require 'yaml'

base = File.dirname( $0 )
[ ".", "..", "src",base + "/.."].each do |dir|
  if test(?f,dir + "/require.rb")
    $: << dir
  end
end
require 'require.rb'


$opt = {
  :mode      => :save,          # save or load 
  :f         => nil,            # output file (デフォルトは標準出力)
  :old       => true,           # 過去の予約データも
  :fo        => false,          # フィルター only
}

OptionParser.new do |opt|
  opt.on('-o')     { $opt[:old] = false }
  opt.on('-s')     { $opt[:mode] = :save }
  opt.on('-l')     { $opt[:mode] = :load }
  opt.on('--fo')   { $opt[:fo] = true }
  opt.on('-f fn')  {|v| $opt[:f] = v }
  opt.parse!(ARGV)
end

reserve = DBreserve.new
filter  = DBfilter.new
data = {}
now = Time.now.to_i

if $opt[:mode] == :save 
  DBaccess.new(DbFname).open do |db|
    db.transaction do
      data[:fil] = filter.select( db )
      if $opt[:fo] == false
        row = reserve.select( db )
        data[:rsv] = row
      end
    end
  end

  str = YAML.dump(data)
  if $opt[:f] != nil
    File.open( $opt[:f], "w" ) do |fp|
      fp.puts(str)
    end
  else
    STDOUT.puts(str)
  end

elsif $opt[:mode] == :load

  if $opt[:f] != nil
    File.open( $opt[:f], "r" ) do |fp|
      str = fp.read()
    end
  else
    str = STDIN.read()
  end
  data = YAML.load( str )

  now = Time.now.to_i
  DBaccess.new().open do |db|
    db.transaction do
      data[:fil].each do |d|
        filter.insert(db, d )
      end
  
      if $opt[:fo] == false
        data[:rsv].each do |d|
          if d[:end] > now or $opt[:old] == true
            d[:id] = nil
            reserve.insert( db, d )
          end
        end
      end
    end
  end

  puts( "DB update; しばらくお待ち下さい。" )
  FilterM.new.update( false )
  
end
