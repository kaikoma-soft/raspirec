#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  予約一覧
#
require 'sys/filesystem'

class LogRote

  Limit = 100 * 1000            # 100k byte 以上
  Max   = 5                     # 残すのは 5世代

  def initialize( )
    @flist = [
      LogFname,
      StdoutM,
      StderrM,
      StdoutH,
      StderrH,
      StdoutT,
      StderrT,
    ]

  end

  #
  #  log ローテーションが必要か？
  #
  def need?()
    @flist.each do |fn|
      size = File.size( fn )
      if size > Limit
        return true
      end
    end
    false
  end

  def exec()
    Max.downto( 1 ) do |n|
      dir = sprintf("%s/old_%02d",LogDir, n )
      if test( ?d, dir )
        if n == Max
          FileUtils.rm_r( dir )
        else
          to = sprintf("%s/old_%02d",LogDir, n +1 )
          File.rename( dir, to )
        end
      end
    end
    to = sprintf("%s/old_%02d",LogDir, 1 )
    Dir.mkdir( to )
    @flist.each do |fn|
      base = File.basename(fn)
      to = sprintf("%s/old_%02d/%s",LogDir, 1,base )
      File.rename( fn, to )
      FileUtils.touch( fn )
    end
  end
end

