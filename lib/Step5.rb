# coding: utf-8

#
#  エンコード
#

class Step5

  def initialize()
  end

  #
  #  エンコードの実行
  #
  def run( para, chap )
    log( "### step5 ###")

    @exec = Libexec.new(para.fpara.tomp4)
    @para = para
    @chap = chap
    if @chap.size < 3
      log( "Error: chapter size < 3 " )
      return
    end

    Log::save( chap.dump( "チャプター割 最終" ), para, "step5.log" ) 

    return if alreadyProc?( para ) == true

    if $opt.forceEnc == false and @para.step4result == false
      log( "Step4 NG -> Step5 skip" )
      return
    end

    ( cmList, honList ) = chapEnc( chap )
    concat(honList, para.mp4fn,  chap, HON)
    concat(cmList,  para.cmmp4fn,chap, CM)
    saveDigest( [ para.chapfn, para.fixfn ], para.chapHash )

    logfn = para.workd + "/ffprobe-out.log"
    if ( ret = outputChk( para.mp4fn, para, logfn )) != nil
      log( ret )
    else
      log( "Error: *** 出力ファイルが正常に出力されませんでした。 ***" )
    end

    #
    # 字幕付加
    #
    if para.subtitle?() == true
      if FileTest.size?( para.subtitlefn ) != nil
        cstt = ConvSubTT.new
        subfn = cstt.run( para.subtitlefn, chap, para )
        if cstt.chk_sub_data( subfn ) == true
          log( "字幕書き込み" )
          setSubtitle( para.mp4fn, subfn, para.mkvfn, para.cmcutLog )
          if FileTest.size?( para.mkvfn ) != nil
            File.unlink( para.mp4fn )
          end
        else
          log( "字幕データが空です。-> 字幕処理 off " )
        end
      end
    end
    
  end


  #
  #  ffmpeg meta情報ファイルを作成
  #
  def makeMeta( para, chap, type )
    buff = [ ";FFMETADATA1","", ]
    #buff << ""
    time = 0.0
    n = 0
    chap.each do |c|
      if c.attr == type or c.attr == EOD
        endt = time + c.w.to_f
        endt -= FrontMargin.to_f if n == 0
        if @para.fpara.fadeOut == true
          endt += FadeOutTime.to_f
        end
        buff << "[CHAPTER]"
        #buff << "TIMEBASE=1/1000"
        buff << "START=#{(time * 1000).to_i * 1000000 }"
        buff << "END=#{(endt * 1000).to_i * 1000000 }"
        #buff << "title=chapter #{n+1}"
        #buff << ""
        time = endt
        n += 1 
      end
    end
    metafn = sprintf("%s/meta-%s.txt", @para.workd, type.to_s)
    File.open( metafn, "w" ) do |f|
      buff.each do |s|
        f.puts(s)
      end
    end
    metafn
  end
    
  #
  #  mp4 の結合
  #
  def concat( list, ofname, chap, type )
    if list.size > 0
      metafn = makeMeta( @para, chap, type  )
      listfname = sprintf("%s/tmp-%s.txt", @para.workd, type.to_s)
      File.open( listfname, "w") do |fp|
        list.each do |fn|
          fp.printf("file %s\n", Shellwords.escape(fn) )
        end
      end
      
      env = { :OUTPUT   => ofname,
              :INPUT    => listfname,
              :METAFN   => metafn,
            }
      makePath( ofname )
      @exec.run( :concat, env, outfn: ofname, log: @para.cmcutLog  )
    end
  end

  
  #
  #  チャプター毎に mp4 化
  #
  def chapEnc( chap )
    i = 1
    cmList = []
    honList = []
    delogo_time = nil

    if @para.fpara.delogo == true
      delogo_time = TArray.new
      delogo_time.load( @para.logoMarkfn )
    end
    
    chap.each do |c|
      next if c.attr != HON and c.attr != CM

      type = c.attr == CM ? "C" : "H"
      outf = sprintf("%s/tmp-%02d-%s.mp4", @para.workd, i, type )

      if FileTest.size?( outf ) != nil and $opt.forceEnc == false
        log("already exists #{File.basename(outf)}")
        if c.attr == CM
          cmList << outf
        else
          honList << outf
        end
        i += 1
        next
      end

      ss = sprintf("%.3f",c.t)
      w  = sprintf("%.3f",c.w)
      metaf = outf.sub(/\.mp4/,".ini").sub(/\/tmp/,"/meta-tmp")
      infn = FileTest.size?( @para.psfn ) != nil ? @para.psfn : @para.tsfn
      env = { :OUTPUT   =>  outf,
              :INPUT    =>  infn,
              :VFOPT    => [],
              :SS       => ss,
              :WIDTH    => w,
              :SIZE     => c.attr == CM ? CMSize : NomalSize,
              :H265PRESET => c.attr == CM ? "-preset ultrafast" : ""
            }

      mono = " -map 0:v:0 -map 0:a:0 "
      if c.attr != CM 
        if @para.fpara.monolingual == 0
          mono = " -map 0:v -map 0:a "
        elsif @para.fpara.monolingual == 1
          mono = " -af pan=mono|c0=c0 "
        elsif @para.fpara.monolingual == 2
          mono = " -ac 1 -map 0:v:0 -map 0:a:0 "
        end
        env[:MONO] = mono

        if @para.fpara.deInterlace != nil and @para.fpara.deInterlace != ""
          env[:VFOPT] << @para.fpara.deInterlace
        end
      end
      
      if @para.fpara.fadeOut == true
        fft = FadeOutTime
        env[:VFOPT] << sprintf("fade=t=out:st=%.2f:d=%.2f", c.w-0.1, fft+0.1)
        env[:WIDTH] = sprintf("%.3f", c.w + fft )
      end

      ss = c.t
      if delogo_time != nil and c.attr == HON
        tmp2 = []
        delogo_time.each do |t|
          next if t.attr == EOD
          s = t.t - ss - 2
          next if s < 0
          tmp2 << sprintf("between(t,%.1f,%.1f)",s , s + t.w + 4 )
        end
        if tmp2.size > 0
          tmp = "delogo=" + @para.fpara.delogo_pos + ":enable="
          env[ :VFOPT ] << tmp + "'" + tmp2.join("+") + "'"
        end
      end

      if @para.fpara.ffmpeg_vfopt != nil
        env[ :VFOPT ] += @para.fpara.ffmpeg_vfopt.split()
      end

      if @para.tsinfo[:width].to_i < 1280
        h = @para.tsinfo[:height].to_i
        w = @para.tsinfo[:width].to_i
        env[ :SIZE ] = sprintf("%dx%d",w,h )
      end
    
      if c.attr == CM
        cmList << outf
      else
        honList << outf
      end

      @exec.run( :tomp4, env, outfn: outf, log: @para.cmcutLog )
      unless fileValid?( outf )
        raise("output check error #{outf}")
        exit
      end
      
      i += 1
    end
    
    return [ cmList, honList ]
  end

  
  
end

  
