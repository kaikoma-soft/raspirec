#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-
#

#
#   YAML の非互換性を吸収するためのラッパー
#

module YamlWrap

  def load_file( fname )
    # pp "load_file() " + Gem::Version.new( Psych::VERSION ).to_s
    if Gem::Version.new( Psych::VERSION ) < Gem::Version.new( "4.0.0" )
      return YAML.load_file( fname )
    else
      return YAML.unsafe_load_file( fname )
    end
  end

  def load( fname )
    # pp "load() " + Gem::Version.new( Psych::VERSION ).to_s
    if Gem::Version.new( Psych::VERSION ) < Gem::Version.new( "4.0.0" )
      return YAML.load( fname )
    else
      return YAML.unsafe_load( fname )
    end
  end

  module_function :load_file
  module_function :load

end

