# coding: utf-8

#
#  解析: セクションの 本編/CM判定
#

class Step3

  def initialize()
    @step3des = Step3des.new()
  end

  def run( para, section )
    @para = para
    @sect = section
    @wav  = para.wav
    @list = {}
    @logo = nil
    @cmlogo = nil
    
    log( "### step3 ###")

    if para.screenS?()
      ( @logo, @cmlogo ) = logoDetection(para)
      Log::save( @logo.dump( "本編ロゴ検出結果" ), para, "step3-1.log"  )
      Log::save( @cmlogo.dump( "CM ロゴ検出結果" ), para, "step3-2.log" )

      if @logo.size < 3
        log("警告: ロゴの検出に失敗しました。")
      end
      @logo.save( para.logoMarkfn ) # logo の存在時間を格納
    end

    if para.fpara.nhk_type == false
      proc10( "*1","CM logo を検出" )
      proc11( "*2","本編 logo を検出" )
      proc13( "*3","本編に挟まれた微小区間を本編に" )

      if para.fpara.sponor_10sec == true
        proc12( "*4","本編の直後にある10秒のセクションは提供とみなす。" )
      end

      if para.fpara.sponsor_search == true
        proc70( "SP","CMの中から提供を探して印を付ける。"  )
      end

      proc32( "*5","微小セクション(4秒以下)を隣とマージして、CM判定")
      proc33( "*6","隣接したセクションの合計が15秒の倍数は CM とみなす。"  )
      proc35( "*7","15秒の倍数のセクションは CM とみなす。"  )
      if para.fpara.cmSec.size > 0
        proc65( "*8","n秒のセクションを強制的にCM にする。"  )
      end

    else
      if @wav == nil or @wav.size == 0
        log("音声データがありません。")
      else
        proc71( "*9", "セクションが全て無音ならば CM とする")
        proc75( "*10","途中にCMはなく、前後に長い無音期間がある。"  )
      end
    end
    proc02( "*11","開始直後の端数は CM にする。" )
    proc40( "*12","開始、終了間際の端数は CM に。"  )
    proc50( "*13","最後まで未判定のものは本編とみなす。"  )
    
    buf = section.dump( "セクション毎の本編／CM 判定結果" )
    buf << ""
    @step3des.each do |a|
      buf << sprintf("  %s : %s",a.key,a.des )
    end
    Log::save( buf, para, "step3-3.log" )
    section.save( para.chapfn )
    @step3des.save( para )      # fixguiで参照する為に保存

    return section
  end

  #
  #  説明を登録
  #
  def regDescription(key, des )
    @step3des.add( key, des )
  end

  def proc13(txt, des)
    regDescription(txt, des )

    size = @sect.size
    @sect.each_with_index do |s,n|
      if s.attr == HON
        if @sect[n+1].attr == NONE
          list = []
          ret = catch(:exit) do
            (n+1).upto(n+4) do |m|
              throw :exit, true  if @sect[m].attr == HON 
              if @sect[m].attr != NONE or
                 @sect[m].w > 10 or
                 size <= m
                throw :exit, false
              end
              list << m
            end
          end
          if ret == true and list.size > 0
            list.each do |m|
              @sect[ m ].attr = HON
              @sect[ m ].addtxt( txt )
            end
          end
        end
      end
    end
    
  end
  
  #
  #   除外パターン
  #
  def proc05(txt, des)
    regDescription(txt, des )

    if Object.const_defined?(:ExcludePat) == true
      ExcludePat.each_pair do |k,v|
        @sect.each_with_index do |s,n|
          if s.attr == NONE
            ret = catch(:exit) do
              begin
                v.each_index do |m|
                  throw :exit, false if @sect[ n + m ].attr == EOD
                  if ( v[m] - @sect[ n + m ].w ).abs > 0.5
                    if m > 0
                      log("proc05() fail #{v[m]} #{(@sect[ n + m ].w).round(1)}")
                    end
                    throw :exit, false
                  end
                end
                throw :exit, true
              end
            end
            if ret == true
              v.each_index do |m|
                @sect[ n + m ].attr = CM
                @sect[ n + m ].addtxt( txt )
              end
            end
          end
        end
      end
    end
  end
  
  
  #
  #   本編の直後にある10秒のセクションは提供とみなす。
  #
  def proc12(txt, des)
    regDescription(txt, des )

    prev = nil
    @sect.each do |s|
      if prev != nil and prev.attr == HON
        if s.attr == NONE
          if Common::cmAnyTime?( [10], s.w )
            s.attr = HON
            s.addtxt( txt )
          end
        end
      end
      prev = s
    end
    
  end

  
  #
  #  最後の端数を併合する。  *** 不使用 ***
  #
  def proc00(txt, des)
    regDescription(txt, des )

    sum = 0
    prev = nil
    @sect.reverse.each do |s|
      next if s.attr == EOD
      if s.attr == NONE or s.attr == CM 
        break if Common::cmTime?( s.w )
        if s.w < 15
          sum += s.w
          break if sum > 20 
          s.delMark = true
          prev = s
        else
          break
        end
      else
        break
      end
    end
    prev.delMark = false if prev != nil

    @sect.del
    @sect.calc
  end
  
  #
  #  
  #
  def proc01(txt, des)
    regDescription(txt, des )

    @sect.each do |c|
      
    end
    
  end
  
  #
  #   開始直後の端数は CM にする。
  #
  def proc02(txt, des)
    regDescription(txt, des )

    @sect.each do |c|
      break if c.attr != NONE or c.w > 10
      c.attr = CM
      c.addtxt( txt )
    end
    
  end

  #
  #   微小セクション(4秒以下)が隣とマージして、CM判定
  #
  def proc32(txt, des)
    regDescription(txt, des )

    def setCM( s,txt )
      s.attr = CM
      s.addtxt( txt )
    end
    
    prev = nil
    @sect.each_with_index do |s,n|
      next if n == 1 or n > ( @sect.size - 3 )
      if s.attr == NONE and s.w < 4.0
        if prev != nil and prev.attr == NONE
          if Common::cmTime?( prev.w + s.w )
            setCM( prev, txt )
            setCM( s, txt )
            next
          end
        end
        if @sect[n+1] != nil and @sect[n+1].attr == NONE
          if Common::cmTime?( @sect[n+1].w + s.w )
            setCM( @sect[n+1], txt )
            setCM( s, txt )
            next
          end
        end
      end
      prev = s
    end
    
  end
  
  #
  #  5秒,10秒の本編を強制的にCM にする。
  #
  def proc65(txt, des)
    regDescription(txt, des )
    
    @sect.each do |c|
      if c.attr == NONE or c.attr == HON
        if Common::cmAnyTime?( @para.fpara.cmSec, c.w )
          c.attr = CM
          c.addtxt( txt )
        end
      end
    end
  end

  class Proc60Data
    attr_accessor :sceneC, :sceneCPS
    def initialize()
      @sceneC   = 0               # シーンチェンジ回数
      @sceneCPS = 0               # シーンチェンジ回数/秒
    end

    def to_s
      sprintf("%3d %4.2f",@sceneC,@sceneCPS)
    end
  end


  #
  #   CMの中から提供を探して印を付ける。
  #
  def proc70(txt, des)
    regDescription(txt, des )

    data = TArray.new
    prev = nil
    any = [ 5,10,15 ]
    @sect.each do |c|
      if c.attr == NONE or c.attr == CM 
        if prev != nil and Common::cmAnyTime?( any, prev.w + c.w )
          data.add( t: c.t, w: (prev.w + c.w),attr: prev.t,val: Proc60Data.new )
        elsif Common::cmAnyTime?( any, c.w )
          data.add( t: c.t, w: c.w, attr: nil, val: Proc60Data.new )
        end
        prev = c
      else
        prev = nil
      end
    end

    data = proc60( data, txt )
    Log::save( data.dump( des ), @para, "step3-proc70.log" )
  end
  


  def proc60( data, txt )
    
    # シーンチェンジの回数をカウント
    @para.scene.each do |scene|
      data.each do |d|
        if scene.t.between?( d.t, d.t + d.w )
          d.val.sceneC += 1
        end
      end
    end

    # 秒当たりに換算
    data.each do |d|
      d.val.sceneCPS = d.val.sceneC.to_f / ( d.w )
    end

    #
    #  当たりがあればそれを本編とする。
    #
    data.each do |d|
      if d.val.sceneCPS <= 0.4
        d.addtxt("Hit")
        @sect.each do |c|
          if c.t == d.t 
            #c.attr = HON
            c.addtxt( txt )
          end
        end
      end
    end

    return data
  end

  #
  # 隣接したセクションの合計が15秒の倍数は CM とみなす。
  #
  def proc33(txt, des)
    regDescription(txt, des )
    
    last = @sect.size
    [ 240, 180, 135, 120, 90, 60, 45, 30, 15 ].each do |target|
      @sect.each_with_index do |c,n|
        if c.attr == NONE or c.attr == CM 
          sum = 0.0
          listW = []              # w の配列
          listN = []              # index の配列
          find = false

          # 最大のリストを作って、そこから減らしていく。
          n.upto( last ) do |m|
            break if @sect[m].attr == HON or @sect[m].attr == EOD
            listW << @sect[m].w
            listN << m
          end
          while listN.size > 1
            if ( listW.sum - target ).abs < SectionGosa
              find = true
              break
            end
            listW.pop
            listN.pop
          end
          
          if find == true and listN.size > 1
            # CMクラスターの値が 30秒以上 又は開始直後ならば CM 化
            sum = 0.0
            listN.min.downto(0).each do |o|
              break if @sect[o].attr == HON
              sum += @sect[o].w
            end
            listN.max.upto(@sect.size).each do |o|
              break if @sect[o].attr == HON or @sect[o].attr == EOD
              sum += @sect[o].w
            end
            sum += listW.sum
            if sum > 29 or ( listN.min < 3 )
              listN.each do |l|
                if @sect[l].attr == NONE
                  @sect[l].attr = CM
                  @sect[l].addtxt( txt )
                end
              end
              #log("proc33() #{txt} ok #{listW.map {|v| v.round(1) }}")
            else
              log("proc33() #{txt} ng #{sum} #{listW.map {|v| v.round(1) }}")
            end
          end
        end
      end
    end
  end
  
  
  #
  # 隣接したセクションの合計が15秒の倍数は CM とみなす。 (旧版)
  #
  def proc33_old(txt, des)
    regDescription(txt, des )

    last = @sect.size
    @sect.each_with_index do |c,n|
      if c.attr == CM or c.attr == NONE
        sum = 0.0
        listW = []              # w の配列
        listN = []              # index の配列
        find = false

        # 最大のリストを作って、そこから減らしていく。
        n.upto( last ) do |m|
          break if @sect[m].attr != NONE
          listW << @sect[m].w
          listN << m
        end
        while listN.size > 1
          if Common::cmTime?( listW.sum )
            find = true
            break
          end
          listW.pop
          listN.pop
        end
                                                   
        if find == true and listN.size > 1
          # CMクラスターの値が 30秒以上 又は開始直後ならば CM 化
          sum = 0.0
          listN.min.downto(0).each do |o|
            break if @sect[o].attr == HON
            sum += @sect[o].w
          end
          listN.max.upto(@sect.size).each do |o|
            break if @sect[o].attr == HON or @sect[o].attr == EOD
            sum += @sect[o].w
          end
          sum += listW.sum
          if sum > 29 or ( listN.min < 3 )
            listN.each do |l|
              if @sect[l].attr == NONE
                @sect[l].attr = CM
                @sect[l].addtxt( txt )
              end
            end
            log("proc33() #{txt} ok #{listW.map {|v| v.round(1) }}")
          else
            log("proc33() #{txt} ng #{sum} #{listW.map {|v| v.round(1) }}")
          end
        end
      end
    end
  end

  
  #
  #  logo を検出
  #
  def proc11(txt, des)
    regDescription(txt, des )
    
    if @logo != nil
      @sect.each do |c|
        next if c.attr != NONE
        margin = c.w > 14 ? 2 : 1
        if c.attr != EOD and logo?( @logo, c.t + margin, c.w - margin * 2)
          c.attr = HON
          c.addtxt( txt )
        end
      end
    end
  end

  # 10秒以上の section が全て無音ならば CM 判定
  def proc71(txt, des)
    regDescription(txt, des )

    @sect.each do |c|
      break if c.attr == EOD
      s = (c.t).round(1)
      e = (c.t + c.w).round(2)
      @wav.each_with_index do |w,n|
        break if w.attr == EOD
        if w.attr == A_OFF 
          s2 = (w.t).round(1)
          e2 = (@wav[n+1].t).round(1)
          if @wav[n+1].attr == A_OFF
            e2 = (@wav[n+2].t).round(1)
          end
          if ( e2 - s2 ) > 10.0
            if s2 <= s and e <= e2
              if c.attr == NONE
                c.attr = CM 
                c.addtxt( txt )
              end
            end
          end
        end
        break if w.t > e
      end
    end
  end
  
  def proc75(txt, des)
    regDescription(txt, des )

    stime = @para.fpara.terminator_stime
    stime = LongSilenceTime if stime == nil
    logstime = stime.to_f / 2
    sep = @para.tsinfo[:duration2] * 0.5
    st = nil
    et = nil
    logd = TArray.new()
    
    @wav.each do |w|
      if w.w != nil and w.attr == A_OFF and w.w > logstime
        logd.add( t: w.t, w:w.w )
      end
        
      if w.w != nil and w.attr == A_OFF and w.w > stime
        if w.t < sep            # 前半
          st = w if st == nil
        elsif w.t > sep         # 後半
          if et == nil
            et = w
          else
            hi = ( w.w / et.w )
            if hi > 3           # 大きい方を優先
              et = w
            end
          end
        end
      end
    end

    tmp = "区切りになる無音時間の候補"
    fn = "step3-proc75.log"
    Log::save( logd.dump( tmp ), @para, fn  )
    
    if st == nil or et == nil
      log("無音期間が見つかりませんでした。設定値を変更して下さい。see #{fn}")
      return
    end

    ss = nil                    # 開始
    es = nil                    # 終了
    @sect.each_with_index do |c,n|
      break if c.attr == EOD
      if c.attr == NONE and c.t > st.t
        ss = n if ss == nil
      end
      if c.t > et.t
        es = n if es == nil
      end
    end

    if ss != nil and es != nil
      @sect.each_with_index do |c,n|
        break if c.attr == EOD
        if n < ss or n >= es
          c.attr = CM
        else
          c.attr = HON
        end
        c.addtxt( txt )
      end
    end
    
  end

  def proc10(txt, des)
    regDescription(txt, des )
    
    if @cmlogo != nil
      @sect.each do |c|
        next if c.attr != NONE
        if c.attr != EOD and logo?( @cmlogo, c.t + 1, c.w - 2 )
          c.attr = CM
          c.addtxt( txt )
        end
      end
    end
  end

  def logo?(logo, t, w)
    logo.each do |l|
      if l.attr == LOGO
        if (l.t).between?( t, t+w ) or
          (l.t + l.w).between?( t, t+w ) or
          t.between?( l.t, l.t + l.w ) 
          return true
        end
        break if l.t > ( t + w )
      end
    end
    return false
  end
  

  
  #
  #  15秒の倍数が連続した場合に CM とみなす。
  #
  def proc35(txt, des)
    regDescription(txt, des )

    #
    #  CM の連続度の算出
    #
    size = @sect.size
    n = 0
    sum = 0
    tmp = []
    while n < size
      if ( @sect[n].w != nil and
           @sect[n].attr == NONE and Common::cmTime?( @sect[n].w ) ) or
        @sect[n].attr == CM 
        m = n
        sum = 0
        while m < size
          if ( @sect[m].w != nil and
               @sect[m].attr == NONE and Common::cmTime?( @sect[m].w ) ) or
            @sect[m].attr == CM
            sum += @sect[m].w
          else
            break
          end
          m += 1
        end
        n.upto(m) {|o| tmp[o] = sum }
        n = m - 1 
      else
        tmp[n] = 0
      end
      n += 1
    end

    #pp tmp
    #pp tmp.size

    @sect.each_with_index do |c,n|
      if c.w != nil and c.attr == NONE
        15.step( 180, 15 ) do |cmt|
          if ( c.w - cmt ).abs <= 0.75
            endm = size - n                            # 終端近く？
            if c.t < 60 or endm < 5 or tmp[n] >= 29.25  # 最小の CM 連続秒数
              c.attr = CM
              c.addtxt( txt )
              break
            end
          end
        end
      end
    end
  end
  
  #
  #  開始、終了間際の端数は CM に。
  #
  def proc40( txt, des )
    regDescription(txt, des )

    [ 0, @sect.size - 2 ].each do |n|
      if @sect[n].w < 180 and ( @sect[n].attr == NONE or @sect[n].attr == HON )
        @sect[n].attr = CM
        @sect[n].addtxt( txt )
      end
    end
  end
  
  #
  #  最後まで未判定のものは本編とみなす。
  #
  def proc50( txt, des )
    regDescription(txt, des )

    @sect.each do |c|
      if c.w != nil and c.attr == NONE
        c.attr = HON
        c.addtxt( txt )
      end
    end
  end

  #
  # opencv を使って logo の検出
  #
  def logoDetection(para)

    data1 = data2 = nil
    dbfnH = "#{para.cached}/resultH.yaml"
    dbfnC = "#{para.cached}/resultC.yaml"
    if $opt.noCache == false
      if test(?f,dbfnH ) == true
        data1 = YAML.load_file( dbfnH )
      end
      if test(?f,dbfnC ) == true
        data2 = YAML.load_file( dbfnC )
      end
      if data1 != nil and data1.size > 2
        log("logoDetection() use cache data")
        return [ data1, data2 ]
      end
    end

    log("logoDetection() runOpencv")

    ( data1, mesg ) = runOpencv( para, HON )
    ( data2, mesg ) = runOpencv( para, CM )
    File.open( dbfnH,"w") { |f| f.puts YAML.dump(data1) }
    File.open( dbfnC,"w") { |f| f.puts YAML.dump(data2) }

    return [ data1, data2 ]
  end
  
  #
  # opencv の実行
  # 
  def runOpencv( para, type = HON )
    now = nil
    last = nil
    old = 0
    mesg = []
    exec = $opt.appdir + "/libexec/logoAnalysisSub.py"
    logofn = type == CM ? para.fpara.cmlogofn : para.fpara.logofn

    data = TArray.new
    data.add( t: 0, attr: NONE )

    logofn.delete( nil )
    if logofn != nil and logofn.size > 0
      arg = %W( #{exec} --dir #{para.picdir} )
      logofn.each {|fn| arg += [ "--logo", $opt.logodir + "/" + fn ] }

      IO.popen( [ PYTHON_BIN, *arg ],"r" ) do |fp|
        fp.each_line do |line|
          if line =~ /^\#/
            mesg << line
          elsif line =~ /^ss_(\d+)\.(png|jpg)\s+[\d\.]+\s+(\d)/
            fn = ( $1.to_f )    
            logo = $3.to_i
            now = ( fn * SS_rate ) - 1 # -1 はオフセット

            if now > 0
              if old != logo
                #printf("%7.1f %d\n", now, logo )
                data.add( t: now, attr: logo == 1 ? LOGO : NONE )
                old = logo
              end
            end
            last = now
          end
        end
      end
    end

    data.add( t: para.tsinfo[:duration2], attr: EOD )
    data.calc()
    
    [ data, mesg ]
  end


  
end

  
