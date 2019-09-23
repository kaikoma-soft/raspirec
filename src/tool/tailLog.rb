#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-

#
#  log の tail
#

require 'optparse'
require 'json'

base = File.dirname( $0 )
[ ".", "..", "src",base + "/.."].each do |dir|
  if test(?f,dir + "/require.rb")
    $: << dir
  end
end
require 'require.rb'


tailLog( )

