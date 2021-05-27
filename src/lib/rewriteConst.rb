# coding: utf-8
#
#  DevAutoDetection で、定数を書き換え
#

def constRewrite( name, val)
  sym = name.to_sym
  base = File.basename($0)
  if Object.const_defined?(sym) == true
    Object.send(:remove_const, sym)
  end
  DBlog::sto("Const rewrite #{base} #{name} = #{val}")
  Object.const_set(sym, val )
end



if Object.const_defined?(:RewriteConst) == true and
  RewriteConst == true and
  Object.const_defined?(:DevAutoDetection) == true and
  DevAutoDetection == true
  if ( data = DeviceChk.new.load()) != nil
    if data.total > 0
      constRewrite( "DeviceList_GR",   data.listGR )
      constRewrite( "DeviceList_BSCS", data.listBC )
      constRewrite( "DeviceList_GBC",  data.listGBC )
    else
      DBlog::error(nil,"デバイスの自動検出に失敗しました。 DevAutoDetection を false にして、手動で設定して下さい。")
    end
  end
end
