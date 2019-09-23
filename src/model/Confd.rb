#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

#
#  
#

class Confd

  def initialize(  )
  end

  def self.read( fname )
    r = []
    if test(?f, fname )
      File.open( fname, "r") do |fp|
        fp.each_line do |line|
          line.sub!(/\#.*/,'').strip!
          if line.size > 0
            r << line
          end
        end
      end
    end
    r
  end
  
end
    
