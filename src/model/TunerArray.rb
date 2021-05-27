# coding: utf-8

#
#  チューナーのリスト
#

class TunerArray < Array

  def initialize( )

    @serial = 0
    GR_tuner_num.times   {|n| add( "GR-#{n+1}",     true,  false)}
    BSCS_tuner_num.times {|n| add( "BS/CS-#{n+1}",  false, true )}
    GBC_tuner_num.times  {|n| add( "GR/BS/CS-#{n+1}",true, true )}
    add( "チューナー不足", false, false, true )

    #
    #  チューナー番号の割り振り
    #
    num = { Const::GR => 0, Const::BSCS => 0, :short => 0 }
    self.each do |tmp|
      num.keys.each do |type|
        if tmp.band[ type ] == true
          num[ type ] +=1
          tmp.num[ type ] = num[ type ]
        end
      end
    end

    #
    #  デバイスファイル名の割り付け
    #
    devGR = DeviceList_GR.dup
    devBC = DeviceList_BSCS.dup
    devGBC = DeviceList_GBC.dup
    serial = 1
    
    self.each do |t1|
      if t1.band[Const::GR] == true and t1.band[Const::BSCS] == true
        t1.devfn = devGBC.shift
      elsif t1.band[Const::GR] == true
        t1.devfn = devGR.shift
      elsif t1.band[Const::BSCS] == true
        t1.devfn = devBC.shift
      end
      t1.serial = serial
      serial += 1

      if t1.devfn != nil
        if FileTest.chardev?( t1.devfn ) or FileTest.blockdev?( t1.devfn )
          t1.stat = :OK
        else
          t1.stat = :NotFond
        end
      end
    end
  end
    
  def add(name, gr, bscs, short = false )
    self << Tuner.new( name, gr, bscs, short )
  end

  #
  #  data の sort
  #
  def allDataSort()
    self.each do |tmp|
      tmp.dataSort()
    end
  end

  #
  #  指定したチューナーを停止 (nil の場合は全部)
  #
  def stop( tunNum = nil )
    n = 0
    self.each do |tmp|
      if tunNum == nil or tunNum == tmp.serial
        n += 1 if tmp.stop() == true
      end
    end
    return n
  end
  
  #
  # 指定したバンドの num番目のチューナーにデータを追加
  #
  def addData( band, num, data )
    self.each do |tmp|
      if tmp.band[band] == true
        if tmp.num[band] == num
          tmp.data << data
          return true
        end
      end
    end
    return false
  end

  #
  # データを全削除
  #
  def allClear( )
    self.each do |tmp|
      tmp.data.clear
    end
  end
  
  #
  #  指定したバンドのチューナーが空いているか
  #
  def unused?(band)
    self.each do |tmp|
      if tmp.band[band] == true
        if tmp.used == false
          return tmp
        end
      end
    end
    return nil
  end

  #
  #  使用中のチューナーの数
  #
  def usedCount()
    count = 0
    #pp "usedCount()"
    self.each do |tmp|
      #pp "usedCount() #{tmp.name} #{tmp.used}"
      if tmp.used == true
        count += 1
        #pp "usedCount() #{tmp.name} #{count}"
      end
    end
    return count
  end
  
  #
  #  short が空ならば削除する
  #
  def delShort()
    return
    self.delete_if do |tmp|
      tmp.band[:short] == true and tmp.data.size == 0
    end
  end

  #
  #  tunerNum, ID を指定してデータの削除
  #
  def deleteData( band, tunerNum, id )
    self.each do |t1|
      if t1.band[band] == true
        if t1.num[band] == tunerNum
          t1.data.delete_if do |t2|
            t2[:id] == id
          end
        end
      end
    end
  end


  #
  #  挿入出来る空き時間があるか？(通常時)
  #
  def insert?( r, jitan = false )
    band = r[:band2]
    st   = r[:start2]
    et   = r[:end2]
    self.each do |t1|
      if t1.band[ band ] == true
        if t1.data.size == 0
          return t1
        else
          t1.data.each_with_index do |t2,n|
            if t1.data[n+1] != nil
              if ( t1.data[n][:end2] < st ) and ( et < t1.data[n+1][:start2] )
                return t1
              end
            else
              if t1.data[n][:end2] < st
                return t1
              end
            end
          end
        end
      end
    end
    return nil
  end

  #
  #  挿入出来る空き時間があるか？(時短適用時)
  #
  def insert_jitan?( r )
    band = r[:band2]
    st   = r[:start2]

    self.each do |tuner|
      if tuner.band[ band ] == true
        tuner.data.each_with_index do |t2,n|

          pet = tuner.data[n][:end3]
          if tuner.data[n+1] != nil # 次がある場合
            nst = tuner.data[n+1][:start2]
          else
            nst = r[:end2] + 9
          end

          # 前番組を時短
          if tuner.data[n][:jitan] == RsvConst::JitanOn
            if pet < st and  r[:end2] < nst
              return [ tuner, [t2] ]
            end

            # 自分も時短
            if r[:jitan] == RsvConst::JitanOn
              if pet < st and r[:end3] < nst
                return [ tuner, [ t2, r ] ]
              end
            end
          end
        end
      end
    end
    return nil
  end

  
  #
  #  debug用 dump
  #
  def dumpData( band, tunerNum )
    self.each do |t1|
      if t1.band[band] == true
        if t1.num[band] == tunerNum
          t1.data.each do |t2|
            puts(">#{Time.at(t2[:start])} - #{Time.at(t2[:end])} #{t2[:title]}")
          end
        end
      end
    end
  end

  #
  # 検索
  #
  def searchDev( devfn )
    self.each do |t|
      return t if t.devfn == devfn
    end
    return nil
  end
  
  #
  #  paly
  #
  def play( tunNum, chid )
    tunNum = tunNum.to_i
    if self[tunNum-1] != nil
      self[tunNum-1].play( chid )
    end
  end
  
  #
  #  使用中のデバイスを検出
  #
  def chkDeviceStat()
    self.each {|t| t.stat = :OK if t.stat != :NotFond }

    lsof = Object.const_defined?(:Lsof_cmd) == true ? Lsof_cmd : "lsof"
    cmd = [ lsof, "+D", "/dev", :err=>[:child, :out] ]
    IO.popen( cmd, "r") do |io|
      io.each_line do |line|
        dev = line.split.last
        if ( t = searchDev( dev )) != nil
          t.stat = :Busy
        end
      end
    end
  end


  #
  #  空いている適当な device名を返す
  #
  def autoSel( chid )
    band = case chid
           when /^BS/ then Const::BSCS
           when /^CS/ then Const::BSCS
           when /^GR/ then Const::GR
           end

    chkDeviceStat()

    self.each do |t|
      if t.band[ band ] == true
        if t.stat == :OK
          return t.serial
        end
      end
    end
    return nil
  end

end
  
