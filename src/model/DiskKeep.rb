# coding: utf-8

#
#   disk の空き容量確保
#
require 'find'
require 'pp'
require 'sys/filesystem'

class DiskKeep

  def initialize(  )
    @gb = 1000 * 1000 * 1000
    @mb = 1000 * 1000
  end

  def start( db )

    return if DiskKeepPercent == nil or DiskKeepPercent == false

    buf = []
    keep = DiskKeepPercent.to_f / 100
    stat = Sys::Filesystem.stat( TSDir )

    total = (stat.blocks * stat.block_size).to_f 
    free = (stat.blocks_available * stat.block_size).to_f
    target = total * keep
    delsize = ( total * keep ) - free

    printf("Disk容量 :  %6.2f GB\n", total / @gb )
    #printf("確保目標 :  %6.2f GB (%.1f%%)\n", target /@gb, keep * 100 )
    #printf("空き容量 :  %6.2f GB (%.1f%%)\n", free / @gb, 100.0 * free / total )
    
    buf << sprintf("削除量 = %6.2f GB", delsize > 0 ? delsize / @gb : 0 )

    if free < ( total * keep )
      list = {}
      Find.find( TSDir ) do |path|
        if test( ?f, path )
          if path =~ /\.ts$/
            fs = File.stat( path )
            list[ fs.mtime ] ||= []
            list[ fs.mtime ] << path
          end
        end
      end

      t = 0
      catch(:break_loop) do
        list.keys.sort.each do |mtime|
          list[ mtime ].each do |path|
            fs = File.stat( path ).size
            t += fs
            buf << sprintf("ファイル削除 %s (%5.1f GB)", File.basename(path),fs / @gb )
            File.unlink( path )
            if t > delsize
              buf << sprintf("削除合計 = %6.1f GB", t/ @gb )
              throw :break_loop
            end
          end
        end
      end
    end

    buf.each do |tmp|
      DBlog::debug( db,"DiskKeep: " + tmp )
    end
  end

  
end

    
