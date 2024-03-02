# coding: utf-8

require 'yaml'
require 'lib/YamlWrap.rb'

#
#  デバイスのチェック
#
class DeviceChk

  attr_reader :data
  
  def initialize( )
  end

  def run( )
    @data = DeviceChkData.new
    yaml = YAML.dump(@data)
    
    File.open( DeviceChkFN, "w") do |fp|
      fp.puts( yaml )
    end
    
    return @data
  end

  def load( )
    @data = nil
    File.open( DeviceChkFN, "r") do |fp|
      @data = YamlWrap.load_file(fp)
    end
    return @data
  end

  #
  # パーミッションのチェック
  #
  def devRWchk( list )
    list.sort.each do |devfn|
      if devfn =~ /frontend0/
        base = File.dirname( devfn )
        chkRW( File.join( base,"demux0" ))
        chkRW( File.join( base,"dvr0" ) )
        chkRW( devfn )
      else
        chkRW( devfn )
      end
    end
  end

  def chkRW( fn )
    if FileTest.chardev?( fn ) or FileTest.blockdev?( fn )
      if FileTest.writable?( fn ) == true and FileTest.readable?( fn ) == true
        # DBlog::sto("device R/W check OK #{fn}")
      else
        DBlog::error(nil, "Error: device R/W check NG #{fn}")
      end
    else
      DBlog::error(nil, "Error: device file not found #{fn}")
    end
  end

  
end


class DeviceChkData

  attr_reader :listGR, :listBC, :listGBC, :total

  GR  = "地デジ"
  BC  = "BS/CS"
  GBC = "GR/BS/CS"
  
  def makeDevName( hina, nums, type )
    nums.each do |n|
      devfn = "/dev/" + sprintf( hina, n )
      if FileTest.chardev?( devfn ) or FileTest.blockdev?(devfn)
        DBlog::sto("device found #{devfn} #{type}")
        case type
        when GR  then @listGR << devfn
        when BC  then @listBC << devfn
        when GBC then @listGBC << devfn
        end
      else
        break
      end
    end
  end
  
  def initialize( )
    
    @listGR = []  # 地デジ
    @listBC = []  # BS/CS
    @listGBC = [] # GR/BS/CS

    numT = [2, 3, 6, 7, 10, 11, 14, 15 ]  # 地デジ
    numS = [0, 1, 4, 5, 8, 9, 12, 13, ]   # BS/CS
    num3 = Array.new(16){|n| n }          # 3波

    numT2 = [1, 3, 5, 7, ]      # dvb ドライバー 地デジ
    numS2 = [0, 2, 4, 6, ]      # dvb ドライバー BS/CS
    
    makeDevName( "px4video%d",numS, BC )      # PX-Q3U4/Q3PE4/Q3PE5
    makeDevName( "pt1video%d",numS, BC )      # PT1/PT2
    makeDevName( "pt3video%d",numS, BC )      # PT3

    makeDevName( "px4video%d",numT, GR )      # PX-Q3U4/Q3PE4/Q3PE5
    makeDevName( "pt1video%d",numT, GR )      # PT1/PT2
    makeDevName( "pt3video%d",numT, GR )      # PT3

    makeDevName( "pxmlt5video%d",  num3, GBC) # PX-MLT5PE
    makeDevName( "pxmlt8video%d",  num3, GBC) # PX-MLT8PE
    makeDevName( "isdb2056video%d",num3, GBC) # DTV02-1T1S-U
    makeDevName( "isdb6014video%d",num3, GBC) # DTV02A-4TS-P

    makeDevName( "dvb/adapter%d/frontend0", numT2, GR ) # dvb
    makeDevName( "dvb/adapter%d/frontend0", numS2, BC ) # dvb

    @total = @listGR.size +  @listBC.size + @listGBC.size

  end

end

if File.basename($0) == "deviceChk.rb"
  DeviceChk.new
end


