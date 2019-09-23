# coding: utf-8


#
#  配管工事
#
def reopenSTD( sto, ste )

  old_out = $stdout.dup
  old_err = $stderr.dup
  $stdin.reopen("/dev/null")
  if $debug == true
    $stdout.reopen( sto, "a")
    $stderr.reopen( ste, "a")
    if false
      $stdout.sync = true
      $stderr.sync = true
    else
      Thread.new do
        while true
          $stdout.flush
          $stderr.flush
          sleep(1)
        end
      end
    end
  else
    $stdout.reopen("/dev/null", "w")
    $stderr.reopen("/dev/null", "w")
  end

  old_out.close
  old_err.close
  #[ old_out, old_err ]
end



#
#  trap の設置
#
def setTrap()

  name = File.basename( $0 )
  Signal.trap( :HUP )  { DBlog::sto("#{name} :HUP") ; endParoc() }
  Signal.trap( :INT )  { DBlog::sto("#{name} :INT") ; endParoc() }
  Signal.trap( :QUIT ) { DBlog::sto("#{name} :QUIT") }
  Signal.trap( :SYS )  { DBlog::sto("#{name} :SYS") }
  Signal.trap( :TERM ) { DBlog::sto("#{name} :TERM") ; endParoc() }
  #Signal.trap( :CHLD ) { DBlog::sto("#{name} :CHLD") }
  Signal.trap( :EXIT) {
    DBlog::sto( name + " " + $! )
    pp $!
  }

  if name == "timer_main.rb"
    Signal.trap( :CHLD ) {
      #DBlog::sto("#{name} :CHLD");
      childWait()  
    }
  end
  
end


def tailLog( out = STDOUT )
  out.puts("tailLog()")
  bsize = 1024 * 1024
  outbuf = "x" * bsize

  fps = []
  [ StdoutH, StdoutT, StderrH, StderrT ].each do |fn|
    if test( ?f, fn )
      fp = open( fn )
      fp.sysseek(0, IO::SEEK_END)
      fps << fp
    end
  end

  count = 0
  while true
    if ( r = IO.select( fps, nil, nil,1 )) != nil
      r[0].each do |fp|
        if fp != nil
          fp.read( bsize, outbuf )
          if outbuf != nil
            outbuf.force_encoding("ASCII-8bit")
            outbuf.each_line do |l|
              next if l =~ /\/var\/lib\//
              next if l =~ /from \/usr\/lib\//
              next if l =~ /style\.css/
              next if l =~ /overlaid\.css/
              next if l =~ /^http:/
              next if l =~ /127\.0\.0/
              next if l =~ /192\.168\.1/
              next if l =~ /\/usr\/lib\/ruby/
              out.write( l )
            end
          end
        end
      end
    end
    sleep(0.1)
  end
end



