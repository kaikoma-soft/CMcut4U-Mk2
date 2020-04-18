#!/usr/bin/ruby
# -*- coding: utf-8 -*-


module Log

  def save( buf, para, fname )

    path = sprintf("%s/%s", para.workd, fname )
    makePath( path )
    File.open( path, "w" ) do |fp|
      fp.puts( buf.join("\n") )
    end
  end
  module_function :save
  
  
end


