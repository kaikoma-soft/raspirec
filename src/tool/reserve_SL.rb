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
  :mode     => :save,          # save or load 
  :fname    => nil,            # output/input file
  :o        => false,          # 過去の予約データ
  :f        => false,          # フィルター only
  :r        => false,          # 予約データ
  :a        => false,          # 自動予約データ
  :C        => false,          # データ削除
  :db       => DbFname,        # DB ファイル
}
$pname   = File.basename( $0 )
$version = "1.1.0"

def usage()
    usageStr = <<"EOM"
Usage: #{$pname} [Options1]  [Options2...]  file

  Options1:
      -s, --save           save モード(デフォルト)
      -l, --load           load モード

  Options2:
      -f, --filter        フィルターデータ
      -a, --auto          自動予約データ
      -r, --reserv        未録画   予約データ
      -o, --old           録画済み 予約データ
      -A, --ALL           全部(-f,-a,-r,-o)
      -d, --db  db_file   DBファイルの指定(デフォルトは config.rb 中の DbFname )
      -C, --clearTable    読み込む前にデータ削除

  file                    入力／出力 ファイル名

#{$pname} ver #{$version}
EOM
    puts usageStr
    exit 1
end

OptionParser.new do |opt|
  opt.on('-s','--save')   { $opt[:mode] = :save }
  opt.on('-l','--load')   { $opt[:mode] = :load }
  opt.on('-d f','--db f') {|v| $opt[:db] = v }

  opt.on('-f','--filter')  { $opt[:f] = true }
  opt.on('-a','--auto')    { $opt[:a] = true }
  opt.on('-r','--reserv')  { $opt[:r] = true }
  opt.on('-o','--old')     { $opt[:o] = true }
  opt.on('-A','--ALL')     { $opt[:f] = $opt[:a] = $opt[:r] = $opt[:o] = true;}
  opt.on('-C','--clearTable')  { $opt[:C] = true; }
  opt.parse!(ARGV)
end

if ARGV.size == 1
  $opt[:fname] = ARGV[0]
else
  usage()
end

reserve = DBreserve.new
filter  = DBfilter.new
data = {}
now = Time.now.to_i

if $opt[:mode] == :save

  data[:fil]  ||= []
  data[:auto] ||= []
  data[:rsv]  ||= []
  data[:old]  ||= []
  
  DBaccess.new( $opt[:db] ).open do |db|
    row = filter.select( db )
    row.each do |r|
      if $opt[:f] == true and r[:type] == 0
        data[:fil] << r
      end
      if $opt[:a] == true and r[:type] == 1
        data[:auto] << r
      end
    end
        
    row = reserve.select( db )
    row.each do |r|
      if $opt[:o] == true and r[:stat] > 1
        data[:old] << r
      elsif $opt[:r] == true and r[:stat] < 2
        data[:rsv] << r
      end
    end
  end

  str = YAML.dump(data)
  if $opt[:fname] != nil and $opt[:fname] != "-"
    File.open( $opt[:fname], "w" ) do |fp|
      fp.puts(str)
    end
  else
    STDOUT.puts(str)
  end

elsif $opt[:mode] == :load

  if $opt[:fname] != nil and $opt[:fname] != "-"
    File.open( $opt[:fname], "r" ) do |fp|
      str = fp.read()
    end
  else
    str = STDIN.read()
  end
  data = YamlWrap.load( str )

  DBaccess.new( $opt[:db] ).open( tran: true ) do |db|

    if $opt[:C] == true
      filter.select( db ).each do |r|
        if ( $opt[:a] == true and r[:type] == 1 ) or 
          ( $opt[:f] == true and r[:type] == 0 )
          filter.delete( db, r[:id] )
        end
      end
      reserve.select( db ).each do |r|
        if ( $opt[:o] == true and r[:stat] > 1 ) or 
          ( $opt[:r] == true and r[:stat] < 2 )
          reserve.delete( db, id: r[:id] )
        end
      end
    end
    
    if $opt[:f] == true
      data[:fil].each do |r|
        r[:id] = nil
        filter.insert( db, r )
      end
    end
    if $opt[:a] == true
      data[:auto].each do |r|
        r[:id] = nil
        filter.insert( db, r )
      end
    end

    if $opt[:o] == true
      data[:old].each do |r|
        r[:id] = nil
        reserve.insert( db, r )
      end
    end
    if $opt[:r] == true
      data[:rsv].each do |r|
        r[:id] = nil
        reserve.insert( db, r )
      end
    end
  end
  
end
