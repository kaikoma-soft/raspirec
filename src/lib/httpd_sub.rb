# coding: utf-8


def makePrgtblUrl( session )
  if session[:from] != nil
    return session[:from]
  else
    if session[:band] != nil and session[:day]  != nil and  session[:time] != nil
      return "/prg_tbl/#{session[:band]}/#{session[:day]}/#{session[:time]}"
    else
      return "/prg_tbl"
    end
  end

end
