#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-
#

# 
#   セクションファイルと Fix ファイルを読んで合成する。
#


module ChapFix
  
  def load( para )

    data = TArray.new
    data.load( para.chapfn )
    data.calc()

    fix = TArray.new
    if test( ?f, para.fixfn )
      fix.load( para.fixfn )
    end
    data.override( fix, "fix" )

    return [ data.sort(), fix ]
  end

  module_function :load
  
end

