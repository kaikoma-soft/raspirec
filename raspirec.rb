# coding: utf-8
#


#
#  main 
#
require 'rubygems'
require 'optparse'
require 'sqlite3'

base = File.dirname( $0 )
$: << base + "/src"

require 'require.rb'


$opt = {
  :f => false,                  # forground
  :lc => false,                 # log clear
  :dc => false,                 # db clear
}
$debug = Debug


OptionParser.new do |opt|
  opt.on('-d') {|v| $debug = true } 
  opt.on('-f') {|v| $opt[:f] = !$opt[:f] } 
  opt.on('--kill') { Control.new.stop(); exit } # kill process
  opt.on('--lc') {|v| $opt[:lc] = true }        # log clear
  opt.on('--dc') {|v| $opt[:dc] = true }        # db clear
  opt.parse!(ARGV)
end

#
#  終了処理
#
def endParoc()
  $endParoc = true
  count = 0
  [ $timer_pid, $httpd_pid ].each do |pid|
    begin
      DBlog::sto( "main::endParoc() kill #{pid}" )
      Process.kill(:TERM, pid );
      count += 1
    rescue
    end
  end
  count.times do |n|
    sleep(1)
    putc(".")
    STDOUT.flush
  end
  exit
end


#
#  デーモン化
#
def daemonStart( )
  if fork                       # 親
    exit!(0) 
  else                          # 子
    Process::setsid
    if fork                     # 親
      exit!(0) 
    else                        # 子
      Dir::chdir("/")
      File::umask(0)

      STDIN.reopen("/dev/null")
      if $debug == true
        STDOUT.reopen( StdoutM, "w")
        STDERR.reopen( StderrM, "w")
      else
        STDOUT.reopen("/dev/null", "w")
        STDERR.reopen("/dev/null", "w")
      end
      yield if block_given?
    end
  end
end


#
#  main loop
#
def mainLoop()
  DBlog::sto("main loop start")

  File.open( PidFile, "w") do |fp|
    fp.puts( Process.pid  )
  end

  pids = []

  
  pids << Thread.new do
    while true
      $timer_pid = fork do
        args = [ "#{SrcDir}/timer_main.rb"]
        args << "--debug" if $debug == true
        exec("ruby", *args )
      end
      DBlog::sto("timer_main start #{$timer_pid}")
      Process.waitpid( $timer_pid )
      DBlog::sto("timer_main end")
      sleep 1
      break if $endParoc == true
    end
  end
  
  pids << Thread.new do
    while true
      $httpd_pid = fork do
        args = [ "#{SrcDir}/httpd_main.rb", "-o", "0.0.0.0"]
        if Http_port != nil and Http_port > 0
          args += [ "-p", Http_port.to_s ]
        end
        args += %w( -- --debug ) if $debug == true
        exec("ruby", *args )
      end
      DBlog::sto("httpd_main start #{$httpd_pid}")
      Process.waitpid( $httpd_pid )
      DBlog::sto("httpd_main end")
      sleep 1
      break if $endParoc == true
    end
  end

  if $opt[:tail] == true
    pids << Thread.new do
      tailLog()
    end
  end
  
  pids.each {|t| t.join}
  
end


#
#  初期化
#
rmlist = []
if $opt[:lc] == true
  rmlist += [
    EPGLockFN,
    DbupdateFN,
    LogFname,
    StdoutM,
    StderrM,
    StdoutH,
    StderrH,
    StdoutT,
    StderrT
  ]
end

if $opt[:dc] == true
  rmlist << DbFname
end

if rmlist.size > 0
  rmlist.each do |fn|
    if test( ?f, fn )
      pp "unlink(#{fn})"
      File.unlink( fn )
      File.open( fn, "w" ) {|fp| } unless fn == DbFname
    end
  end
  exit
end




#
# 初期化
#

[ DataDir, LogDir, JsonDir, DBDir, TSDir, StreamDir ].each do |dir|
  Dir.mkdir( dir ) unless test( ?d, dir )
  raise "can not make dir(#{dir})" unless test( ?d, dir )
end

File.open( MainLockFN, File::RDWR|File::CREAT, 0644) do |fl|
  if fl.flock(File::LOCK_EX|File::LOCK_NB) == false
    puts("raspirec locked\n")
    exit
  end

  [ EPGLockFN ].each do |fn|
    if test(?f, fn )
      File.unlink( fn )
    end
  end
  $rec_pid = {}
  $endParoc = false

  setTrap()
  
  if $opt[:f] == false
    daemonStart{ mainLoop() }
  else
    mainLoop()
  end
end



