#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-
#
#


class Ffmpeg

  def initialize( ts )
    unless test( ?f, ts )
      raise "ts file not found (#{ts})"
    end
    @tsfn = ts
    @bin = FFMPEG_BIN
  end
  
  #
  #  実行時間表示付き system
  #
  def system2( bin, *cmd )
    log( sprintf("%s %s",bin,cmd.join(" ") ))
    system( bin, *cmd )
  end


  #
  #  ffprob
  #
  def getTSinfo( logfn = nil )

    logfp = nil
    r = {}
    r[ :fname ] = @tsfn
    r[ :subtitle ] = false if r[ :subtitle ] == nil
    keys = %w( width height codec_long_name duration field_order display_aspect_ratio codec_name )
    arg = [  ]
    arg += %W( -pretty -hide_banner -show_streams  #{@tsfn} )
    logfp = File.open( logfn, "w" )  if logfn != nil
    logfp.printf( "%s\n\n",arg.join(" ") ) if logfp != nil
    
    IO.popen( ["ffprobe", *arg], "r",:err=>[:child, :out] ) do |fp|
      fp.each_line do |line|
        line = NKF::nkf("-w",line.chomp)
        logfp.puts( line ) if logfp != nil
        keys.each do |k|
          if line =~ /^#{k}=(.*)/
            if $1 != "N/A"
              r[ k.to_sym ] = $1 if r[ k.to_sym ] == nil
            end
          end
        end
        if line =~ /^\s+Duration: (.*?),/
          r[ :duration ] = $1 if r[ :duration ] == nil and $1 != "N/A"
        end
      end
    end

    if r[:duration] != nil
      if r[:duration] =~ /(\d):(\d+):([\d\.]+)/
        r[:duration2] = $1.to_i * 3600 + $2.to_i * 60 + $3.to_f
      end
    end


    #
    #   TS の場合、誤検出を避ける為に前番組の部分を skip して再度 ffprobe
    #
    require "open3"

    r[ :AudioStream ] = []
    if @tsfn =~ /\.ts$/
      if ( size = File.size( @tsfn )) != nil
        logfp.puts( "\n\n" + "-" * 20 + "\n\n") if logfp != nil
        cmd = %w( ffprobe - )
        bsize = 1024 * 1024 
        outbuf = "x" * bsize
        pid = nil
        Open3.popen3( *cmd ) do |stdin, stdout, stderr, th|
          pid = Thread.fork do
            File.open( @tsfn, "r" ) do |fp|
              begin
                fp.seek( size / 10 ) 
                while ( line = fp.read( bsize, outbuf ) ) != nil
                  stdin.write( line )
                end
              rescue Errno::EPIPE, IOError
              rescue => e
                p $!
                e.backtrace.each {|s| puts s }
              end
              stdin.close    # または close_write
            end
          end

          begin
            while ( stdout.eof? == false or stderr.eof? == false )
              IO.select([stderr, stdout]).flatten.compact.each do |io|
                io.each_line do |line|
                  line.force_encoding("ASCII-8BIT")
                  if line =~/Stream \#0:(\d+)\[.*?\]: Audio/
                    r[ :AudioStream ] << $1.to_i
                    #pp "Audio Stream #{$1}"
                  elsif line =~ /Subtitle: arib_caption/
                    r[ :subtitle ] = true
                  end
                  logfp.puts line if logfp != nil
                end
              end
            end
          rescue EOFError,Errno::EPIPE
          rescue => e
            p $!
            e.backtrace.each {|s| puts s }
          end
        end
      end
    end

    logfp.close if logfp != nil
    return r
  end

  
  


  #
  #  mp4
  #
  def mp4enc( para, outf = nil )

    outf = para.mp4fn if outf == nil
    env = { :OUTPUT   =>  outf,
            :INPUT    => para.tsfn,
            :VFOPT    => [],
            :monolingual => para.fpara.monolingual,
            :SS       => 0,
            :WIDTH    => para.tsinfo[:duration2],
            :H265PRESET => ""
          }

    h = para.tsinfo[:height].to_i
    w = para.tsinfo[:width].to_i
    env[ :SIZE ] = sprintf("%dx%d",w,h )

    if para.fpara.deInterlace != nil and para.fpara.deInterlace != ""
      env[:VFOPT] << para.fpara.deInterlace
    end
    
    exec = Libexec.new(para.fpara.tomp4)
    exec.run( :tomp4, env, outfn: outf )
    
    unless fileValid?( outf )
      raise("output check error #{outf}")
      exit
    end

  end

  #
  #  wav 変換
  #
  def ts2wav( opt )
    arg = @logLevel +
          %W( -threads #{$max_threads} -i #{@tsfn} ) +
          %W( -vn -ac 1 -ar #{WavRatio} -acodec pcm_s16le -f wav ) +
          %W( -y #{opt[:outfn]} ) 
    system2( @bin, *arg )
  end
  

end


