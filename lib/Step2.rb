# coding: utf-8

#
#  解析: チャプターを生成
#

class Step2

  def initialize()

  end

  def run( para )
    log( "### step2 ###")

    wav = wav_ana( para )
    para.wav = wav.copy
    wav = wav_longOff( para, wav )
    Log::save( wav.dump( "無音時間の検出" ), para, "step2-1.log" )
    at = wav.last.t
    vt = para.tsinfo[:duration2]
    sa = ( vt - at ).abs.round(2)
    if sa > 1.0
      log("警告: 映像(#{vt}秒)と音声(#{at}秒)の時間に差(#{sa}秒}があります。")
    end
    
    scene = scene_ana( para )
    para.scene = scene
    Log::save( scene.dump( "シーンチェンジ" ), para, "step2-2.log" )

    section = makeSection( wav, scene, para )
    Log::save( section.dump( "セクション 原案(1)" ), para, "step2-4.log" )

    # シーンチェンジから漏れた無音期間を救済
    t = leakGap( wav )
    any = [ 5, 10, 20, 30, 60 ]
    15.step( 180, 15 ) { |v| any << v }
    t.each do |t2|
      ( p, n ) = section.distance( t2[0] )
      w = t2[1]
      if t2[0] < 12 or
        Common::cmAnyTime?( any, p, 0.75 + w ) or
        Common::cmAnyTime?( any, n, 0.75 + w  )
        t3 = section.insertData( t2[0], t2[1] )
        log("leakGap() add #{t3.round(2)}")
      else
        log("leakGap() ignore #{t2[0].round(2)}")
      end
    end
    section.sort()
    Log::save( section.dump( "セクション 原案(2)" ), para, "step2-4.log" )

    return section
  end


  
  #
  #  チャプター毎の平均音量を算出
  #
  def wav_ave( para, chap )

    f = open(para.wavfn)
    format, chunks = WavFile::readAll(f)
    f.close

    #puts format.to_s if $opt.debug

    dataChunk = nil
    chunks.each{|c|
      #puts "> #{c.name} #{c.size}"
      dataChunk = c if c.name == 'data' # find data chank
    }
    if dataChunk == nil
      puts 'no data chunk'
      exit 1
    end

    bit = 's*' if format.bitPerSample == 16 # int16_t
    bit = 'c*' if format.bitPerSample == 8  # signed char
    wavs = dataChunk.data.unpack(bit)       # read binary
  
    if format.channel == 1 or format.channel == 2
      num = 0
      averageC = 0.0
      last = wavs.size - 1
      j = 0
      chapNum = 0
      s = 0
      while j < last
        if format.channel == 1
          i = wavs[j].abs
        else
          i = ( wavs[j].abs + wavs[j+1].abs ) / 2
        end

        # 音量の平均値(チャプター毎)
        averageC = ( ( num * averageC) + i) / (num + 1)
        num += 1

        break if chap[chapNum+1] == nil
        if chap[chapNum+1].t < j.to_f / WavRatio
          chap[chapNum].val = averageC
          averageC = 0.0
          num = 0
          chapNum += 1
        end
          
        j += format.channel
      end
    else
      raise "ill wav format"
    end

    # 全体の音量平均値
    tmp = []
    w = 0.0
    chap.each do |c|
      if c.val != nil
        tmp << c.val * c.w 
        w += c.w
      end
    end
    averageA = tmp.sum / w

    return averageA
  end
  
  #
  #  微小区間を隣と併合する。
  #
  def mergeChapter( chap )
    while mergeChapter2( chap ) == true
      chap.del
      chap.calc
    end
    chap
  end
  
  def mergeChapter2( chap )
    last = chap.size - 1
    n = 0
    while n < last 
      if chap[n].w < 4.0
        sum = 0
        m = n
        list = []
        while m < last and ( chap[n].t + 4.0 ) > chap[m].t
          sum += chap[m].w
          list << m
          m += 1
        end
        15.step(300,15) do |o|
          if ( sum - o ).abs < 0.5
            list.shift
            list.each {|p| chap[p].delMark = true }
            return true
          end
        end
      end
      n += 1
    end
    false
  end

  #
  #  SilenceTime 秒以上なのにシーンチェンジがなかったものを抽出
  #
  def leakGap( wav )
    ret = []
    wav.each do |w|
      if w.attr == A_OFF and w.w > SilenceTime
        if w.val != true
          ret << [ w.t,  w.w ]
        end
      end
    end
    ret
  end
  
  #
  #  SilenceTime 秒以上の無音期間に当たっているか?
  #
  def silence?( t, wav )
    wav.each do |w|
      if w.attr == A_OFF and w.val != true
        if w.w >= SilenceTime
          if t.between?( w.t, w.t + w.w )
            w.val = true
            return true
          end
        end
      end
      break if t < w.t
    end
    false
  end
  
  #
  #  セクションの生成
  #
  def makeSection( wav, scene, para  )
    prev = 0.0
    data = TArray.new
    data.add( t: 0, attr: NONE )
    scene.each do |s|
      if silence?( s.t, wav ) == true
        data.add( t: s.t )
        prev = s.t
      end
    end
    data.add( t: para.tsinfo[:duration2], attr: EOD )
    data.calc
    return data
  end

  #
  #  シーンチェンジ取得
  #
  def scene_ana( para )
    if FileTest.size?( para.sceneCfn ) != nil

      cachefn = para.cached + "/sceneC.yaml"
      if $opt.noCache == false
        if FileTest.size?( cachefn ) != nil
          data = YAML.load_file( cachefn )
          if data != nil and data.size > 2
            return data
          end
        end
      end

      data = TArray.new
      File.open( para.sceneCfn ) do |fp|
        fp.each_line do |line|
          line.force_encoding("ASCII-8BIT")
          if line =~ /pts_time:([\d\.]*)/
            t = $1.to_f
            data.add( t: t )
          end
        end
      end
      data.calc

      File.open( cachefn,"w") { |f| f.puts YAML.dump(data) }
      
      return data
    else
      raise "#{para.sceneCfn} not found"
    end
  end
  
  #
  #  音声情報の読み込み : 無音区間の検出
  #
  def wav_ana( para )
    if FileTest.size?( para.wavfn ) != nil

      cachefn = para.cached + "/wav.yaml"
      if $opt.noCache == false
        if FileTest.size?( cachefn ) != nil
          data = YAML.load_file( cachefn )
          if data != nil and data.size > 2
            return data
          end
        end
      end
      
      f = open(para.wavfn)
      format, chunks = WavFile::readAll(f)
      f.close

      #puts format.to_s if $opt.debug == true

      dataChunk = nil
      chunks.each{|c|
        #puts "> #{c.name} #{c.size}"
        dataChunk = c if c.name == 'data' # find data chank
      }
      if dataChunk == nil
        puts 'no data chunk'
        exit 1
      end

      bit = 's*' if format.bitPerSample == 16 # int16_t
      bit = 'c*' if format.bitPerSample == 8  # signed char
      wavs = dataChunk.data.unpack(bit)       # read binary
  
      data = TArray.new
      data.add( t: 0, attr: A_ON ) # start of data

      sw = ( WavRatio / 10 * 1 )   # 0.1 秒以上
      total_num = 0
      average = 0.0
      last = wavs.size
      j = 0
      level = 10                 # 無音レベル
      if format.channel == 1
        while j < last
          i = wavs[j].abs
          if i < level                 # 無音レベルの探索
            k2 = j
            j.step( wavs.size-1,1 ) do |k|
              if wavs[k].abs > level
                k2 = k
                break
              end
            end
            if ( k2 - j ) > sw
              data.add( t: (j.to_f / WavRatio), attr: A_OFF )
              data.add( t: (k2.to_f / WavRatio), attr: A_ON )
            end
            j = k2
          end
          j += 1
        end
      else
        raise "ill wav format"
      end
      data.add( t: (last.to_f / WavRatio), attr: EOD )
      data.calc()

      File.open( cachefn,"w") { |f| f.puts YAML.dump(data) }
      
      return data
    else
      raise( "wav file not found (#{para.wavfn})" )
    end
  end


  #
  #  長い無音期間の最後をシーンチェンジ用に分割する。
  #
  def wav_longOff( para, wav )

    buf = []
    wav.each do |w|
      if w.attr == A_OFF and w.w > 3.0
        buf << w
      end
    end

    buf.each do |w|
      wav.add( t: (w.t + w.w - 1.5), w: (w.w - 1.5), attr: A_OFF, txt: "分割" )
    end
    wav.sort
    
    return wav
  end



end

