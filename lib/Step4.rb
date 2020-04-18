# coding: utf-8

#
#  チェック
#

class Step4

  
  def initialize()
  end
  
  def run( para )
    @para = para

    log( "### step4 ###")

    (chap, fix ) = ChapFix::load( para )
    if chap.size == 0
      log("Error: chapter size 0")
      return
    end

    (chap2, sum ) = mkTimetable( chap )
    
    total   = 0.0
    chapNum = 0
    pAttr   = nil
    chap2.each do |c|
      total += c.w if c.attr == HON
      if pAttr != c.attr
        chapNum += 1
        pAttr = c.attr
      end
    end

    dflag = "×"
    @para.fpara.duration.each do |d|
      if ( total - d ).abs < TotalGosa
        dflag = "○"
        break
      end
    end

    cflag = "×"
    @para.fpara.chapNum.each do |c|
      if c == chapNum
        cflag = "○"
        break
      end
    end

    tmpc = @para.fpara.chapNum.join(",")
    tmpd = @para.fpara.duration.join(",")
    len = tmpc.size > tmpd.size ? tmpc.size : tmpd.size
    tmpc = tmpc.rjust( len )
    tmpd = tmpd.rjust( len )
    tmpt = "期待値".center( len - 1)

    buf = []
    buf << "***** 期待値照合 *****"
    buf << ""
    buf << "           |#{tmpt}|  計算値  |   結果"
    buf << "-" * ( 35 + len )
    buf << sprintf("本編時間   | %s | %8.2f |   %s", tmpd,total,dflag )
    buf << sprintf("チャプタ数 | %s | %8d |   %s", tmpc,chapNum,cflag )
    buf << ""

    ret = ( cflag == "○" and dflag == "○" ) ? true : false
    if $opt.chkng == true
      if ret == false
        puts("#{@para.subdir}/#{@para.fnbase2}")
        buf.each {|b| puts(b) } 
      end
    else
      log( buf )
      #buf.each {|b| puts(b) }
    end

    if ret == true
      $result.incOk()
      @para.step4result = true
      FileUtils.touch( @para.step4okfn )
    else
      $result.incNg()
      File.unlink( @para.step4okfn ) if test(?f, @para.step4okfn )
    end
    
    return [ ret, chap2 ]
  end

  #
  #  カット割の生成
  #
  def mkTimetable( chap )
    type = nil
    data = TArray.new
    sum = { HON => 0.0, CM => 0.0}
    chap.each do |c|
      if type != c.attr
        type = c.attr
        data.add( t: c.t, attr: c.attr )
      end
      if c.w != nil
        sum[ c.attr ] ||= 0.0
        sum[ c.attr ] += c.w
      end
    end
    data.calc

    buff = data.dump( "最終チャプター割" )
    buff << "-" * 36 
    buff << sprintf("%-12s %8.2f","honpen",sum[HON])
    buff << sprintf("%-12s %8.2f","CM",sum[CM])
    buff << "-" * 36
    buff << sprintf("%-12s %8.2f","Total",sum[CM] + sum[HON])
    log( buff )
    
    return [ data, sum ]
  end

  
end

  
