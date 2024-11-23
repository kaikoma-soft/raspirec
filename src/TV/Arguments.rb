# coding: utf-8

require 'optparse'

class Arguments

  attr_reader :x                # x座標
  attr_reader :y                # y座標
  attr_reader :w                # 幅
  attr_reader :h                # 高さ
  attr_reader :font             # font名
  attr_reader :d                # debug level 
  attr_reader :round            # 巡回ボタン
  attr_reader :epg              # EPG 取得
  
  def initialize(argv)
    @x = @y = @w = @h = @font = nil
    @round = nil
    @d = 0
    @epg = false

    if Object.const_defined?( :RaspirecTV_font ) == true
      @font = RaspirecTV_font
    end
    if Object.const_defined?( :RaspirecTV_GEO ) == true
      geoConv( RaspirecTV_GEO )
    end
    
    op = option_parser
    op.parse!(argv)
  rescue OptionParser::ParseError => e
    $stderr.puts e
    exit(1)
  end

  private

  def option_parser
    OptionParser.new do |op|
      op.on('-g', '--geometry WxH+X+Y','座標指定(WxH+X+Y or +X+Y)') { |t|
        geoConv( t )
      }
      op.on('-f', '--font font_name','font指定 (例："Sans 14")'){ |t|
        @font = t
      }
      op.on('-r', '--round time',Integer,'巡回ボタン表示(time=巡回時間(秒))'){ |t|
        @round = t.to_i
      }
      op.on('-e', '--epg','EPG取得'){ |t|
        @epg = true
      }
      op.on('-d', '--debug','debug mode'){ |t|
        @d += 1
      }
    end
  end

  #
  #  座標の数値化  WxH+X+Y
  #
  def geoConv( geo )
    if geo =~ /^(\d+)x(\d+)\+(\d+)\+(\d+)$/
      @w, @h, @x, @y = $1.to_i,$2.to_i,$3.to_i,$4.to_i
    elsif geo =~ /^(\d+)\+(\d+)$/
      @x, @y = $1.to_i,$2.to_i
    else
      
    end
  end

end

#
#  debug 出力
#
def dlog( str, level = 0 )
  if $arg != nil
    if $arg.d > level
      puts( str )
    end
  end
end

