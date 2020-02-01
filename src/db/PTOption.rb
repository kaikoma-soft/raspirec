# coding: utf-8
#
#  番組表のオプション のload/save
#
class PTOption

  SP = "StationPage"
  HP = "HourPixel"
  HN = "HourNum"
  TT = "ToolTip"

  attr_reader  :sp, :hp, :tt, :hn
  
  def initialize(  )
    keyval = DBkeyval.new 
    DBaccess.new().open do |db|
      @sp = keyval.select( db, SP )
      @hp = keyval.select( db, HP )
      @hn = keyval.select( db, HN )
      @tt = keyval.select( db, TT )
    end

    @sp = StationPage if @sp == nil
    @hp = 180         if @hp == nil
    @hn = 6           if @hn == nil
    if @tt == nil
      @tt = true
    else
      @tt = @tt == 1 ? true : false
    end
  end

  def save( para )
    hp = para["range1"]
    hn = para["range2"]
    sp = para["range3"]
    tt = para["tooltip"] == "on" ? 1 : 0

    keyval = DBkeyval.new 
    DBaccess.new().open do |db|
      @sp = keyval.upsert( db, SP, sp )
      @hp = keyval.upsert( db, HP, hp )
      @hn = keyval.upsert( db, HN, hn )
      @tt = keyval.upsert( db, TT, tt )
    end
  end
  
end
