# coding: utf-8

#
#   多重起動防止
#

module EpgLock

  def lock?() 
    if test( ?f, EPGLockFN )
      now = Time.now
      mtime = File.mtime( EPGLockFN )
      if mtime > ( now - 3600 * 1)  # 1時間以内
        #DBlog::sto( "Error: Lock file exist")
        return true
      end
    end
    false
  end
  module_function :lock?

  def lock()
    FileUtils.touch(EPGLockFN)
  end
  module_function :lock

  def unlock()
    if test(?f, EPGLockFN )
      File.unlink( EPGLockFN )
    end
  end
  module_function :unlock
  
end

    
