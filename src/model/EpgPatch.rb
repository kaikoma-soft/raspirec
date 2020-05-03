#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  EPG データにパッチ当て
#

class EpgPatch

  def initialize(  )
    
  end

  def getData()
    data = {}
    dir = $baseDir + "/../EpgPatch"
    Dir.open( dir ).each do |fname|
      if fname =~ /(.*?)\.dat$/
        path = dir + "/" + fname
        dataRead( path, data )
      end
    end
    return data
  end
  
  def dataRead( fname, data )
    chid = nil
    if test(?f, fname )
      File.open( fname, "r") do |fp|
        fp.each_line do |line|
         line.sub!(/\#.*/,'')
          if line != nil and line.size > 0
            line.strip!
            if line =~ /^\[(.*)\]/
              chid = $1.strip
            elsif line =~ /\s*(\S+)\s+(.*)/
              if chid != nil
                data[chid] ||= {}
                data[chid][ $1.to_sym ] = $2.strip
              end
            end
          end
        end
      end
    end
    data
  end
  
end

  
    
