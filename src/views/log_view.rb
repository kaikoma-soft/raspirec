# coding: utf-8

class LogView

  Base = "/log_view"
  
  def initialize( level, page )
    @radio = { :debug => false,
               :info  => false,
               :atte  => false,
               :warn  => false,
               :err   => false,
             }
    if level != nil
      case level.to_i
      when DBlog::Debug      then @radio[:debug] = true
      when DBlog::Info       then @radio[:info] = true
      when DBlog::Attention  then @radio[:atte] = true
      when DBlog::Warning    then @radio[:warn] = true
      when DBlog::Error      then @radio[:err] = true
      end
      @level = level.to_i
    else
      @level = 2
      @radio[:info] = true
    end

    if page == nil
      @page = 1
    else
      @page = page.to_i
    end
    @page_line = 256

    @data = getData()
  end

  #
  #  pageのセレクト
  #
  def pageSel( )
    r = []
    r << %Q{<ul class="pagination inline-block">}
    1.upto( @pageNum ) do |p|
      cl = "waves-effect"
      cl += " active" if @page == p
      href = sprintf("%s/%d/%d",Base,@level,p)
      r << %Q{    <li class="#{cl}"><a href="#{href}">#{p}</a></li>}
    end
    r << %Q{</ul>}
    
    r.join("\n")
  end

  def getData()
    log = DBlog.new
    ret = []
    DBaccess.new().open do |db|
      @total_size = log.count( db, level: @level - 1)
      @pageNum = 1
      if @total_size > @page_line
        @pageNum = @total_size / @page_line
        if @pageNum > 0
          @pageNum += 1 if (@total_size - ( @page_line * @pageNum )) > 0
        end
      end
      limit = nil
      if @pageNum > 1
        limit = "LIMIT #{@page_line} OFFSET #{@page_line * (@page - 1 )}"
      end
      ret = log.select( db, level: @level - 1, limit: limit )
    end
    ret 
  end
  
  def printTable()
    log = DBlog.new
    ret = []
    @data.each do |r|
      r.shift
      if r[0] >= @level 
        tdcl = %w( nowrap )
        r[0] = case r[0]
               when DBlog::Debug     then "デバッグ"
               when DBlog::Info      then "情報"
               when DBlog::Attention then tdcl << "atte" ; "注意"
               when DBlog::Warning   then tdcl << "warn" ; "警告"
               when DBlog::Error     then tdcl << "error" ; "エラー"
               end
        r[1] = Time.at( r[1] ).strftime("%Y-%m-%d %H:%M:%S")
        ret << Commlib::printTR2( r, tdcl: tdcl )
      end
    end
    ret.join("\n")
  end

  def radio()
    @radio
  end
  
end
