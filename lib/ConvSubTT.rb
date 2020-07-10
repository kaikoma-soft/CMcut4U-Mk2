# coding: utf-8

#
#   字幕タイミングの変換
#
class ConvSubTT

  DumpFn = "/tmp/CSTT.tmp"
  
  def initialize(  )
  end
  
  def run( assfn, chap, para )
    tofn = assfn.sub(/\.ass/,"-2.ass")

    if para.fpara.subadj != nil and para.fpara.subadj != 0.0
      log("字幕タイミング調整 #{para.fpara.subadj} 秒")
    end
    
    firstTime = nil
    File.open( tofn, "w") do |fpw|
      File.open( assfn, "r") do |fpr|
        fpr.each_line do |line|
          if line =~ /^(Dialogue:\s+\d),([\d:.]+),([\d:.]+),(.*)/
            prefix = $1
            st = hms2f( $2 )
            et = hms2f( $3 )
            suffix = $4
            if firstTime == nil
              tmp = suffix.split(/,/).last
              tmp = delDecoration( tmp )
              if tmp.size > 0
                firstTime = f2hms( st )
                log("字幕先頭 = #{firstTime}  #{tmp}")
              end
            end
            r = conv( st, et, chap, para )
            if r != nil
              (st2, et2 ) = r 
              st3 = f2hms( st2 )
              et3 = f2hms( et2 )
              #pp "#{st} -> #{st2} -> #{st3}"
              #pp "#{et} -> #{et2} -> #{et3}"
              #puts
              fpw.printf("%s,%s,%s,%s\n",prefix,st3,et3,suffix)
            end
          else
            fpw.puts( line )
          end
        end
      end
    end
    if File.size?( tofn ) != nil
      return tofn
    end
    return nil
  end

  def delDecoration( str )
    tmp = str.dup
    [ /\r/,
      /{\\r}/,
      /{\\fscx\d+\\fscy\d+}/,
      /{\\.*?&}/,
      /　/,
      /\s+/,
    ].each do |reg|
      tmp.gsub!(reg,'')
    end
    return tmp
  end
  
  def conv( st, et, chap, para )
    del = 0.0
    hit = nil
    adj = 0.0
    adj += para.fpara.subadj if para.fpara.subadj != nil

    if chap != nil
      chap.each do |c|
        if st.between?( c.t, c.t + c.w )
          hit = c
          break
        end
        del += c.w if c.attr == :cm
        if para.fpara.fadeOut == true and c.attr == :hon
          adj += FadeOutTime.to_f
        end
      end
      raise "no hit #{st}"  if hit == nil
    end
    #pp "hit #{del} #{hit.attr} #{hit.t} #{hit.w} #{adj}"
    st -= del - adj
    et -= del - adj
    st = 0.0 if st < 0
    et = 0.0 if et < 0
    return [ st, et ]
  end
  
  def hms2f( hms )
    f = 0.0
    if hms =~ /(\d+):(\d+):([\d\.]+)/
      h, m, s = $1, $2, $3
      f = h.to_f * 3600 + m.to_f * 60 + s.to_f
    end
    f
  end

  def f2hms( t )
    return Time.at( t ).utc.strftime('%-H:%M:%S:%2N')
  end
  
  def saveChap( chap )
    str = Marshal.dump( chap )
    File.open( DumpFn, "w" ) do |fp|
      fp.puts(str)
    end
  end

  def loadChap()
    File.open( DumpFn, "r" ) do |fp|
      return Marshal.load(fp.read())
    end
  end

  #
  #  字幕ファイル(ass)が有効の検査 (true = 有効)
  #
  def chk_sub_data( subfn )
    c = 0
    if File.size?( subfn ) != nil
      File.open( subfn,"r") do |fp|
        fp.each_line do |line|
          if line =~ /^Dialogue:/
            tmp = line.split(/,/).last.chomp
            tmp = delDecoration( tmp )
            if tmp != nil and tmp != ""
              c += 1
            end
          end
        end
      end
    end
    return true if c > 1
    return false 
  end
  
end


if $0 == __FILE__
  require_relative 'TArray.rb'

  cstt = ConvSubTT.new
  pp chap = cstt.loadChap()
  pp cstt.run( "subtitle.ass", chap )
end
