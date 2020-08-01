# coding: utf-8

#
#  タイミングチャートのデータ
#
class TArray < Array

  class Val
    attr_accessor :scFlag      # シーンチェンジと適合したか

    def initialize( )
      @scFlag = false
    end
                  
  end
  
  class Data
    attr_accessor :t,             # 時間
                  :w,             # 幅
                  :attr,          # 属性(オプション)
                  :val,           # 値(オプション)
                  :txt,           # コメント欄(オプション)
                  :delMark        # 削除印
    
    def initialize( t ,w, attr, val = nil , txt = nil )
      @t = t.class == Float ? t.round(2) : t
      @w = w
      @attr = attr == nil ? NONE : attr
      @val = val
      @txt = txt
      @delMark = false
    end

    def addtxt( txt )
      if @txt == nil
        @txt = txt
      else
        @txt += " " + txt
      end
    end

    def attr2str( )
      str = case @attr
            when A_OFF  then "off"
            when A_ON   then "on"
            when HON    then "HonPen"
            when CM     then "CM"
            when NONE   then "None"
            when LOGO   then "Logo"
            when SOD    then "start"
            when EOD    then "EOD"
            end
      return str
    end

    def copy()
      return Data.new( self.t, self.w, self.attr, self.val, self.txt )
    end
    
  end

  def initialize()
    super()
  end

  def add( t: nil, w: nil, attr: nil, val: nil, txt: nil )
    self << Data.new( t, w, attr, val, txt )
  end

  #
  #  途中に値を挿入。その時、前後との間隔を 15秒に合わせられるなら合わせる
  #
  def insertData( t, w, attr = NONE )
    #pp "insert() start"
    index = nil
    tm = nil
    self.each_with_index do |a,n|
      if t.between?( a.t, a.t + a.w )
        # 後
        b = a.t + a.w
        15.step( 120, 15 ) do |m|
          if ( b - m ).between?( t, t+w )
            tm = b - m
            break
          end
        end
        # 前
        15.step( 120, 15 ) do |m|
          if ( a.t + m ).between?( t, t+w )
            tm = a.t + m
            break
          end
        end
        tm = t + w * 0.5 if tm == nil # 当たりが無かった場合
        index = n + 1
        break
      end
      calc()
    end

    self.insert( index, Data.new( tm, 0, attr, nil, nil )) if index != nil

    return tm.to_f
  end
  
  def addValue()
    self.each do |a|
      a.val = Val.new( )
    end
  end

  #
  #  指定ポイントの前後の距離を返す
  #
  def distance( t )
    self.each_index do |n|
      next if self[n].attr == EOD 
      if t.between?( self[n].t, self[n+1].t )
        return [ (t - self[n].t).abs, ( self[n+1].t - t ).abs ]
      end
    end
    return nil
  end
  
  #
  #  指定したポイントが含まれるか？
  #
  def include?( t )
    self.each do |s|
      return s if s.t == t
    end
    return nil
  end
  
  #
  #  w の計算
  #
  def calc()
    self.each_with_index do |x,y|
      if x.attr != EOD and y != self.size - 1
        x.w = self[ y + 1 ].t - x.t
      end
    end
  end

  def sort()
    self.sort! do |a,b|
      a.t <=> b.t
    end
    calc()
  end
  
  #
  #
  #
  def  del()
    self.delete_if do |tmp|
      if tmp.delMark == true
        true
      end
    end
  end

  #
  #  dump
  #
  def dump( text = nil, opt = true )
    ret = []
    if text != nil
      ret << "*****  #{text}  *****\n"
    end
    hms = ""
    self.each_with_index do |x,y|
      attr = x.attr2str( )
      if x.val.class == Float
        val = sprintf("%8.1f",x.val)
      elsif x.val.class == Integer
        val = sprintf("%8d",x.val)
      else
        val = x.val.to_s
      end
      txt = x.txt == nil ? "" : x.txt
      if opt == true
        hms = " (" + Common::sec2min( x.t ) + ")"
      end
      ret << sprintf("%3d  %8.2f%s  %8.2f  %-8s  %-8s  %s",
                     y, x.t.to_f, hms, x.w.to_f, attr, txt, val)
    end
    #ret << ""
    ret
  end

  #
  #  data の save
  #
  def save( fname )
    #fname = para.chapfn
    makePath( fname )
    if File.open( fname, "w") do |fp|
         self.each do |s|
           type = s.attr2str( )
           t = Common::sec2min( s.t )
           fp.printf( "%s  %-8s %s\n",t, type, s.txt )
         end
       end
    end
  end

  #
  #  data のload
  #
  def load( fname )
    #fname = para.chapfn
    return self if FileTest.size?( fname ) == nil
    File.open( fname, "r") do |fp|
      fp.each_line do |line|
        next if line =~ /^#/
        if line =~ /^([\d:\.]+)\s+(\w+)\s+(.*)/
          time,type,txt = $1,$2,$3
          type = case type
                 when "CM"     then CM
                 when "HonPen" then HON
                 when "EOD"    then EOD
                 when "Logo"   then LOGO
                 when "None"   then NONE
                 else
                   p type
                   raise
                 end
          if time =~ /(\d+):(\d+):([\d.]+)/
            time = ( $1.to_f * 3600 + $2.to_f * 60 + $3.to_f )
            self.add( t: time, attr: type, txt: txt )
          end
        end
      end
    end
    self.calc()
  end

  #
  #  attr の上書き
  #
  def override( other, txt = nil )

    other.each do |o|
      flag = false
      self.each do |s|
        if o.t == s.t
          s.attr = o.attr
          s.addtxt( txt ) if txt != nil
          flag = true
        end
      end
      if flag == false
        log("override() fail #{o.to_s}")
      end
    end
  end

  #
  #
  #
  def copy()
    copy = TArray.new
    self.each do |s|
      copy << s.copy
    end
    return copy
  end
end
