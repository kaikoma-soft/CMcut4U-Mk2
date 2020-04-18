# coding: utf-8

require 'optparse'
require 'open3'

class Libexec

  def initialize( tomp4 = nil )
    @list = {
      :tomp4     => "to_mp4.sh",
      :towav     => "to_wav.sh",
      :sceneC    => "sceneChanges.sh",
      :screenS   => "screenShot.sh",
      :tojpg     => "to_jpg.sh",
      :logoana   => "logoAnalysisSub.py",
      :container => "containerConv.sh",
      :concat    => "concat.sh",
    }

    # :tomp4 の設定優先順位は  引数 > パラメータファイル > config > デフォルト
    fn = if $opt.tomp4 != nil
           $opt.tomp4
         elsif tomp4 != nil
           tomp4
         elsif Object.const_defined?(:ToMp4) == true
           ToMp4
         else
           "to_mp4.sh"
         end

    path = $opt.appdir + "/libexec/" + fn
    if FileTest.file?( path )
      if FileTest.executable?( path )
        @list[ :tomp4 ] = fn
      end
    end
  end

  def run( name, env, outfn: nil, args: nil, log: nil )
    
    if @list[ name ] == nil
      raise("Error: name(#{name.to_s}) not found")
    else
      path = $opt.appdir + "/libexec/" + @list[ name ]
      if FileTest.file?( path )
        if FileTest.executable?( path )
          if env != nil
            env.each_pair do |k,v|
              k = k.to_s if k.class == Symbol
              v = v.join(",") if v.class == Array
              ENV[ k ] = v.to_s
            end
          end
          ENV["FFMPEG"] = FFMPEG_BIN
          ENV["LOGLEVEL"] = $opt.debug == true ? "info" : "fatal"
          ENV["NO_COLOR"] = ""
          ENV["VFOPT"] = "null" if ENV["VFOPT"] == ""
          
          $workFile << outfn if outfn != nil
          st = Time.now
          #system( path, *args )
          Open3.popen3( path, *args ) do |i, o, e, t|
            i.close
            begin
              fpw = log != nil ? File.open( log, "a") : nil
              loop do
                IO.select([o, e]).flatten.compact.each do |io|
                  io.each do |line|
                    next if line.nil? || line.empty?
                    fpw.puts line if fpw != nil
                    if $opt.debug == true or line =~ /^Error/
                      puts line
                    end
                  end
                end
                break if o.eof? && e.eof?
              end
            rescue EOFError
            ensure
              fpw.close if fpw != nil
            end
          end
          $workFile.delete( outfn )
          lap = Time.now - st
          w = env[:WIDTH].to_f
          speed = w / lap
          if speed > 0
            outf = File.basename(env[:OUTPUT])
            log( sprintf("%6.2f Sec (%4.1fx)  %s %s",
                         lap, speed, File.basename(path), outf ))
          else
            log( sprintf("%6.2f Sec %s %s",
                         lap, File.basename(path), outf ))
          end
            
        else
          raise("Error: #{path} is not executable")
        end
      else
        raise("Error: #{path} not found")
      end
    end
  end

end
