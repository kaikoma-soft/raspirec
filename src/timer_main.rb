# coding: utf-8

require 'pp'
require 'optparse'

base = File.dirname( $0 )
[ ".", "..","src", base ].each do |dir|
  if test( ?f, dir + "/require.rb")
    $: << dir
    $baseDir = dir
  end
end
require 'require.rb'

$debug = Debug
OptionParser.new do |opt|
  opt.on('--debug') {|v| $debug = true } 
  opt.parse!(ARGV)
end

reopenSTD( StdoutT, StderrT )

#
#  終了処理
#
def endParoc()
  DBlog::puts( "endParoc() #{$httpd_pid}" )
  if $rec_pid != nil
    $rec_pid.each_pair do |pid, v |
      if pid != nil
        begin
          Process.kill(:HUP, pid );
          Process.waitpid( pid, Process::WNOHANG )
        rescue Errno::ECHILD
        end
        DBlog::puts( "timer:endParoc() kill #{pid}" )
      end
    end
  end
  sleep(1)
  exit
end

$rec_pid = {}                   # 子プロセス の pid
$mutex = Mutex.new

#
#  :CHLD のハンドラ
#
def childWait()
  #DBlog::sto("childWait()")
  Thread.new do
    sleep(10)                   # 時間差をつける
    $rec_pid.keys.each do |k|
      if $rec_pid[k] == true
        begin
          if Process.waitpid( k, Process::WNOHANG ) != nil
            DBlog::sto("timer:childWait() pid=#{k} Terminated") # 成仏
            $rec_pid.delete(k)
          end
        rescue Errno::ECHILD
          $rec_pid.delete(k)
        end
      end
    end
  end
end

#
#  メモリの使用量調査
#
def memSpace( db = nil )
  require 'objspace'
  mem = ObjectSpace.memsize_of_all * 0.001 * 0.001
  rss = `ps -o rss= -p #{Process.pid}`.to_i * 0.001
  gcc = GC.count
  tmp = sprintf("memsize_of_all=%.2f MB ; RSS=%.2f MB ; GCC=%d",mem,rss, gcc)
  DBlog::debug(db, tmp )
end

  
setTrap()

File.open( TimerPidFile, "w") do |fp|
  fp.puts( Process.pid  )
end

DBlog::debug( nil,"timer main start" )
EpgLock::unlock()

#
# tool check
#
tools = [ Recpt1_cmd,  Epgdump ]
tools.each do |tool|
  unless test( ?x, tool )
    foundF = false
    ENV["PATH"].split(/:/).each do |p|
      if test( ?x, "#{p}/#{tool}" )
        foundF = true
        break
      end
    end
    if foundF == false
      DBlog::error( nil, "Error: #{tool} not found" )
    end
  end
end

if $debug == true and Debug_mem == true
  Thread.new do
    while true
      memSpace( nil )
      sleep( 600 )
    end
  end
end

tm = Timer.new
tm.start()


  

