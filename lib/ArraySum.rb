# coding: utf-8

#
#  ruby 2.3 以前は Array に sum() が無いので追加
#

class Array

  def sum()
    sum = 0.0
    self.each do |i|
      sum += i
    end
    return sum
  end

end
