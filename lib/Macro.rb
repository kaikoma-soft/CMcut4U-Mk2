# coding: utf-8

#
#  マクロ定義
#
class Macro < Array

  class SyntaxError < StandardError
    attr_reader :mes
    def initialize( mes = "" )
      super
      @mes = mes
    end
  end

  module Comm

    #
    #  設定値
    #
    def typeAna( type )
      r = case type
          when "CM","Cm","C" then CM
          when "HON","Hon","H" then HON
          else
            raise SyntaxError, "設定値(#{type})"
          end
      return r
    end

    #
    #  条件
    #
    def condAna( cond )
      cond2 = condS = condE = nil
      condType = :section
      
      if cond =~ /^S(\d+)/i
        cond2 = $1.to_i
      elsif cond =~ /last/i
        cond2 = :last
      elsif cond =~ /^(UNI|U|SUM|ADD|A)([\d\:\.]+)-([\d\:\.]+)/i
        condS = timeConv( $2 )
        condE = timeConv( $3 )
        condType = case $1
                   when /UNI/i, "U", "u" then :uni
                   else 
                     :sum
                   end
      else
        raise SyntaxError,"条件(#{cond})"
      end
      return [ condType, condS, condE, cond2 ]
    end

    #
    #  時間の文字列 1:23:00.5 or 3600.5 をfloat に変換
    #
    def timeConv( str )
      ret = 0
      if str =~ /(\d+):(\d+):([\d\.]+)/
        ret = ($1.to_f) * 3600 + ($2.to_f) * 60 + ($3.to_f)
      elsif str =~ /(\d+):([\d\.]+)/
        ret = ($1.to_f) * 60 + ($2.to_f)
      elsif str =~ /([\d\.]+)/
        ret = ($1.to_f)
      else
        raise SyntaxError,"時間指定(#{str})"
      end
      ret
    end
  end


  
  class Ctype
    attr_reader :line
    include Comm
    
    def initialize( target, cond, type )

      @cond     = nil
      @condType = :section
      
      if target =~ /^C(\d+)/i
        @target = $1.to_i
      else
        raise SyntaxError,"範囲(#{target})"
      end

      @condType, @condS, @condE, @cond = condAna(cond )
      @type = typeAna( type )

      @line = "#{target} #{cond} #{type}"
    end

    #
    #  判定処理
    #
    def proc( sect, txt )
      attr = nil
      chapter = 0
      section = 1
      onTarget = false
      ret = []
      sect.each_with_index do |s,n|
        if attr != s.attr
          chapter += 1
          section = 1 
          attr = s.attr
        end
        if chapter == @target
          onTarget =  true
        else
          if onTarget == true and @cond == :last
            ret << [ sect[n-1], @type, txt ]
            return ret
          end
          onTarget =  false
        end

        break if s.attr == EOD

        if onTarget == true
          if @condType == :section and section == @cond
            ret << [ s, @type, txt ]
            return ret
          end
          if @condType == :uni and s.w.between?( @condS, @condE )
            ret << [ s, @type, txt ]
            next
          end
          if @condType == :sum     # 合計
            sum = 0
            list = []
            n.upto( sect.size ) do |m|
              break if sect[m].attr == EOD or sum > @condE
              sum += sect[m].w
              list << m
              if sum.between?( @condS, @condE )
                list.each do |j|
                  if sect[j].attr != @type
                    ret << [ sect[j], @type, txt ]
                  end
                end
                break
              end
            end
          end
        end
        #pp "C=#{chapter} S=#{section} T=#{onTarget}"
        section += 1
      end
      return ret
    end
    
  end
  
  
  class Ttype

    attr_reader :line
    include Comm
    
    def initialize( target, cond, type )

      if target =~ /^T([\d:\.]+)-([\d:\.]+)/i
        @targetS = timeConv( $1 )
        @targetE = timeConv( $2 )
      else
        raise SyntaxError,"範囲(#{target})"
      end

      @condType, @condS, @condE, @cond = condAna(cond )
      @type = typeAna( type )

      @line = "#{target} #{cond} #{type}"

    end

    #
    #  判定処理
    #
    def proc( sect, txt )

      onTarget = false
      ret = []
      sect.each_with_index do |s,n|
        break if s.attr == EOD
        if @targetS < s.t and s.t < @targetE
          onTarget =  true
        else
          onTarget =  false
        end
        if onTarget ==  true
          if @condType == :uni     # 単体
            if @condS <= s.w and s.w <= @condE
              if s.attr != @type
                ret << [ s, @type, txt ]
                next
              end
            end
          elsif @condType == :sum     # 合計
            sum = 0
            list = []
            n.upto( sect.size ) do |m|
              break if sect[m].t > @targetE or sect[m].attr == EOD
              sum += sect[m].w
              list << m
              if @condS <= sum and sum <= @condE
                list.each do |j|
                  if sect[j].attr != @type
                    ret << [ sect[j], @type, txt ]
                  end
                end
                break
              end
            end
          end
        end
      end
      ret
    end

    
  end
  
  
  def initialize()
    super()
  end

  #
  #  data のload
  #
  def load( fname )
    errC = 0
    File.open( fname, "r") do |fp|
      fp.each_line do |line|
        line.chomp!
        line.gsub!(/_/,'')
        next if line =~ /^#/ or line == ""
        tmp = line.split
        begin
          if tmp.size > 2
            case tmp[0][0]
            when "C","c"
              tmp2 = Ctype.new( *tmp[0..2] )
              self << tmp2
            when "T","t"
              tmp2 = Ttype.new( *tmp[0..2] )
              self << tmp2
            else
              raise SyntaxError, "範囲(#{tmp[0]})"
            end
          else
            raise SyntaxError, ""
          end
        rescue SyntaxError => e
          log("マクロ定義エラー: #{e.mes} : #{line}")
          errC += 1
        end
      end
    end
    if errC > 0
      log("#{errC} Error in #{fname}")
    end
    
  end


end
