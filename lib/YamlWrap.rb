#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-
#

# 
#   YAML の非互換性を吸収するためのラッパー
#

module YamlWrap
  
  def load_file( fname )
    if Gem::Version.new( Psych::VERSION ) < Gem::Version.new( "4.0.0" )
      return YAML.load_file( fname )
    else
      return YAML.unsafe_load_file( fname )
    end
  end

  module_function :load_file
  
end

