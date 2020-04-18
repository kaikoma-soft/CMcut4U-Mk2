# coding: utf-8

#
#  前処理
#

class Step1

  def initialize()
    @exec = Libexec.new
  end

  def run( para )

    if para.fpara.containerConv == true
      log( "### コンテナ変換 ###")
      psfn = para.psfn
      if FileTest.size?( psfn ) == nil
        env = { "INPUT" => para.tsfn,
                "OUTPUT" => psfn,
            }
        @exec.run( :container, env, outfn: psfn, log: para.cmcutLog  )
        if FileTest.size?( psfn ) != nil
          para.tsfn = psfn
        else
          log( "Error: コンテナ変換に失敗しました。")
        end
      end
    end
    
    log( "### step1 ###")
    makeWav( para )
    sceneChanges( para )
    if para.fpara.audio_only != true or para.fpara.delogo == true
      makeJpg( para )
    end
  end

  
  #
  #  シーンチェンジ検出
  #
  def sceneChanges( para )
    if FileTest.size?( para.sceneCfn ) == nil
      env = { "INPUT" => para.tsfn,
              "OUTPUT" => para.sceneCfn,
            }
      @exec.run( :sceneC, env, outfn: para.sceneCfn, log: para.cmcutLog  )
    end
  end

  #
  # wav化
  #
  def makeWav( para )
    if FileTest.size?( para.wavfn ) == nil
      env = { "INPUT" => para.tsfn,
              "OUTPUT" => para.wavfn,
              "WAVRATIO" => WavRatio,
            }
      @exec.run( :towav, env, outfn: para.wavfn, log: para.cmcutLog  )
    end
  end

  #
  # screen shot
  #
  def makeJpg( para )

    head = para.picdir + "/ss_00001.jpg"
    return if test( ?f, head  )
    
    ffmpeg = Ffmpeg.new( para.tsfn )
    info = para.tsinfo
  
    max = info[:duration2 ]
    h = info[:height].to_f
    w = info[:width].to_f

    unless test(?d, para.picdir )
      FileUtils.mkpath( para.picdir )
    end

    #  0,0    w
    #   +-------+---+
    #   |TL     |TR |
    #   |       +---+ h
    #   |           |
    #   |BL      BR |
    #   +-----------+
    #
    
    w2 = (w * 0.18).round(2)
    h2 = (h * 0.2).round(2)
    case para.fpara.position
    when "top-right"
      x2 = (w * 0.8).round(2)
      y2 = 0
    when "top-left"
      x2 = 0
      y2 = 0
    when "bottom-left"
      x2 = 0
      y2 = (h * 0.8).round(2)
    when "bottom-right"
      x2 = (w * 0.8).round(2)
      y2 = (h * 0.8).round(2)
    else         
      raise "position format error (#{para.fpara.position})"
    end

    env = {
      "INPUT"  => para.tsfn,
      "OUTPUT" => "#{para.picdir}/ss_%05d.jpg",
      "W"      => w2,
      "H"      => h2,
      "X"      => x2,
      "Y"      => y2,
      "FRAMERATE"  => SS_frame_rate,
      "VFOPT"      => (max * Fps).to_i,
    }

    @exec.run( :tojpg, env, outfn: head, log: para.cmcutLog  )

    return para.picdir
  end
end


