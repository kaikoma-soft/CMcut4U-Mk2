# coding: utf-8


require 'pp'
require 'fileutils'
require 'wav-file'
require 'nkf'
require 'shellwords'
require 'openssl'
require 'find'
require 'yaml'
require "tempfile"

require_relative 'Arguments.rb'
require_relative 'Const.rb'
require_relative 'Ffmpeg.rb'
require_relative 'Libexec.rb'
require_relative 'Log.rb'
require_relative 'Para.rb'
require_relative 'Step1.rb'
require_relative 'Step2.rb'
require_relative 'Step3.rb'
require_relative 'Step4.rb'
require_relative 'Step5.rb'
require_relative 'read_config.rb'
require_relative 'TArray.rb'
require_relative 'common.rb'
require_relative 'ParaFile.rb'
require_relative 'ChapFix.rb'
require_relative 'Step3des.rb'
require_relative 'Result.rb'
require_relative 'ConvSubTT'
require_relative 'Macro.rb'

if Array.method_defined?(:sum) == false
  require_relative 'ArraySum.rb'
end
