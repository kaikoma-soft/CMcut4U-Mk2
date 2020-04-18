# coding: utf-8

#
#   総合結果
#
class Result

  attr_accessor :total, :ng, :ok, :encFin, :encWait
  
  def initialize()
    @total   = 0
    @ng      = 0
    @ok      = 0
    @encFin  = 0
    @encWait = 0
    @skip    = 0
  end

  def incNg()
    @ng    += 1
    @total += 1
  end

  def incOk()
    @ok    += 1
    @total += 1
  end

  def incSkip()
    @skip  += 1
    @total += 1
  end

  def print()
    return if @total == 0
    
    printf("TS ファイル     %4d\n", @total)
    printf("check NG        %4d\n", @ng)
    printf("check OK        %4d\n", @ok)
    printf("skip            %4d\n", @skip)
    printf("エンコード済み  %4d\n", @encFin)
    printf("エンコード待ち  %4d\n", @encWait)
  end
  
end
