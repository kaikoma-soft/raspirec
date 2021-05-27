# coding: utf-8

#
#  直近(10分)の予約がある物理チャンネルを返す。
#  前回の履歴から重複はしないように
#

class EpgNearCh

  @@updT = { }                  # chid 毎の EPG更新時間(短縮)
  
  def initialize( t = 600 )
    @sepTime = t                # 連続とみなす予約間隔
  end
  
  #
  # 直近に録画番組がある局のEPG 取得のために、更新時間を細工
  #  @sepTime は予約間の隙間の許容値
  #
  def check(  )

    #DBlog::stoD("EpgNearCh::check()")
    st = et = nil
    reserve = DBreserve.new
    phchid  = DBphchid.new
    channel = DBchannel.new
    keyval  = DBkeyval.new
    nearTime = Time.now.to_i + 60 * 10 # 直近とは 10分以内
    now      = Time.now.to_i
    list = []
    res = []

    DBaccess.new().open do |db|
      db.transaction do

        row = reserve.selectSP( db, stat: RsvConst::Normal, order: "order by start" )
        if row.size == 0 or ( row.first[:start] > nearTime )
          return []
        end
        
        # 直近の連続した予約を抽出
        row.each do |r|
          if st == nil
            st = r[:start] 
            et = r[:end]
            list << r
          else
            if r[:start].between?( st, et + @sepTime )
              et = et > r[:end] ? et : r[:end]
              list << r
            else
              break
            end
          end
        end

        updtime = {}               # chid 毎の EPG更新時間(正規)
        row = phchid.select( db )
        row.each do |tmp|
          chid = tmp[:chid]
          if updtime[chid] == nil or updtime[chid] < tmp[:updatetime]
            updtime[chid] = tmp[:updatetime]
          end
        end

        chid2phch = channel.makeChid2Phch(db)
        
        list.each do |r|
          chid = r[:chid]
          phch = chid2phch[ chid ]
          flag = false
          if updtime[chid] < ( now - 10 * 60 )
            if @@updT[chid] == nil or @@updT[chid] < ( now - 10 * 60 )
               flag = true
            end
          end
          # if $debug == true
          #   sa1 = r[:start] - now
          #   sa2 = now - updtime[chid]
          #   sa3 = now - ( @@updT[chid] == nil ? now : @@updT[chid] )
          #   mark = flag == true ? "+" : " "
          #   tmp = sprintf("%s %6s 録 %5d 秒前 EPG1 %5d 秒前 EPG2 %5d 秒前 %s",
          #                 mark, phch, sa1,sa2,sa3, r[:title])
          #   DBlog::stoD(tmp)
          # end
          if flag == true
            @@updT[chid] = now
            res << phch
          end
        end
        res.uniq!
        
        if res.size > 0
          DBlog::debug( db,"EpgNearCh #{res.join(" ")}" )
        end
      end
    end
    return res
  end


  def ppp()
    pp @@updT
  end

end


if File.basename($0) == "EpgNearCh.rb"
  base = File.dirname( $0 )
  [ ".", "..","src", base ].each do |dir|
    if test( ?f, dir + "/require.rb")
      $: << dir
      $baseDir = dir
    end
  end
  require 'require.rb'

  $debug = true
  ge = EpgNearCh.new
  pp ge.check()
  ge.ppp()

  exit
  
  
end


