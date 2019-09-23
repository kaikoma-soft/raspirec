#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'fileutils'

class DBupdateChk

  def initialize( )
    if test(?f, DbupdateFN )
      @mtime = File.mtime( DbupdateFN )
    else
      @mtime = Time.at(0)
    end
  end

  def touch()
    FileUtils.touch(DbupdateFN)
  end

  def update?()
    if test(?f, DbupdateFN )
      mtime = File.mtime( DbupdateFN )
      if mtime > @mtime
        @mtime = mtime
        return true
      end
    end
    false
  end
end
