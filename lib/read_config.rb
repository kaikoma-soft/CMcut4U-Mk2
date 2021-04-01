# coding: utf-8

#
#  config の読み込み
#
def read_config()
  ret = nil
  files = [ ]
  files << $opt.config if $opt != nil and $opt.config != nil
  files << ENV["CMCUT4U2_CONF"] if ENV["CMCUT4U2_CONF"] != nil
  files << ENV["HOME"] + "/.config/CMcut4U2/config.rb"
  files << File.dirname($0) + "/config.rb"
  files.each do |cfg|
    if test( ?f, cfg )
      require cfg
      ret = cfg
      break
    end
  end
  raise "counfig not found" if Object.const_defined?(:Workdir) != true
  ret
end

