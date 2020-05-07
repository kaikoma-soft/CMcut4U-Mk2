# coding: utf-8
#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-
#

#
#  ファイル名等の各種パラメータを生成、格納
#
class Para

  attr_accessor :tsfn,          # TSファイル名
                :basedir,       # dirname(tsfn)
                :chapHash,      # チャプターリストの hash値保存ファイルのPATH
                :chapfn,        # チャプター情報ファイル名
                :cmcutLog,      # log ファイルPATH
                :subdir,        # sub dir 名
                :fnbase,        # basename(tsfn) 拡張子なし
                :fnbase2,       # basename(tsfn) 拡張子あり
                :logoMarkfn,    # ロゴ検出データの保存ファイルのPATH
                :metafn,        # meta情報ファイルのPATH
                :mp4fn,         # 本編 mp4 ファイル PATH
                :cmmp4fn,       # CM mp4 ファイル PATH
                :parafn,        # パラメータファイルPATH
                :picdir,        # スクリーンショットDir Path
                :sceneCfn,      # シーンチェンジ検出結果ファイル名
                :wavfn,         # wav ファイルPATH
                :workd,         # 作業Dir PATH
                :wav,           # 音声データ
                :fpara,         # パラメータファイルの値の格納
                :fixfn,         # Fixファイル名
                :cached,        # データキャッシュDir
                :scene,         # シーンチェンジ データ
                :step3desfn,    # Step3 の処理の説明文
                :step4result,   # Step4の結果
                :step4okfn      # Step4 が OK の場合に touch
  
  
  
  
  def initialize( apath: nil, base: nil )
    @tsfn  = apath                 # TS file name

    if base != nil
      @basedir = base
      @subdir  = File.dirname( apath.sub(/#{base}\//,''))
    else
      @basedir = File.dirname( apath )
      @subdir  = nil
    end
    @fnbase  = File.basename( apath, ".*")
    @fnbase2 = File.basename( apath )
    @ext     = File.extname( apath ) 
    @parafn = sprintf("%s/para.yaml", File.dirname( apath ))

    if @subdir != nil
      @mp4fn  = sprintf("%s/%s/%s.mp4",$opt.outdir,@subdir,@fnbase )
      @workd  = sprintf("%s/%s/%s", $opt.workdir, @subdir, fnbase )
    else
      @mp4fn  = sprintf("%s/%s.mp4",$opt.outdir,@fnbase )
      @workd  = sprintf("%s/%s", $opt.workdir, fnbase )
    end
    @cmmp4fn  = @workd + "/cm-all.mp4"

    @cmcutLog  = @workd + "/cmcut.log"
    1.upto(9999).each  do |n|
      tmp = sprintf("%s/cmcut-%02d.log",@workd, n )
      next if test( ?f, tmp )
      @cmcutLog  = tmp
      break
    end
    @wavfn     = @workd + "/Tmp.wav"
    @sceneCfn  = @workd + "/SceneC.dat"
    @picdir    = @workd + "/SS"
    @metafn    = @workd + "/ffmeta.ini"
    @chapHash  = @workd + "/chapList.sha"
    @chapfn    = @workd + "/chapList.txt"
    @fixfn     = @workd + "/chapFix.txt"
    @logoMarkfn= @workd + "/logoMark.log"
    @cached    = @workd + "/Cache"
    @step3desfn= @workd + "/Cache/s3des.yaml"
    @cutSkip   = false
    @step4result = false
    @step4okfn = @workd + "/step4.ok"
    
  end


  def setLogofn( str )
    @logofn = sprintf("%s/%s",LogoDir,str )
    return nil unless test(?f,@logofn )
    @logofn
  end


  #
  #  TSの諸元取得
  #
  def tsinfo( log = nil )
    if @tsinfoData == nil
      @tsinfoData = Ffmpeg.new( @tsfn ).getTSinfo( log )
    end
    return @tsinfoData
  end

  #
  # パラメータファイルの読み込み
  #
  def readParaFile()
    if FileTest.size?( @parafn ) != nil
      @fpara = ParaFile.new().readPara( para: self )
      @fpara.logofn.compact!
      @fpara.cmlogofn.compact!
      return @fpara
    end
    return nil
  end

  def psfn()                    # ts -> mp4 変換後のファイル名
    return @workd + "/" + @fnbase + ".mp4"
  end

end
  

