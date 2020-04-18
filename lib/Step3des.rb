# coding: utf-8

#
#   Step3 の説明文の格納
#
class Step3des < Array

  class Data
    attr_accessor :key, :des    # Description
    def initialize(key, des)
      @key = key
      @des = des
    end
  end
  
  def initialize()
    super()
  end

  def add( key, des )
    self << Data.new( key, des )
  end

  def save(para)
    
    File.open( para.step3desfn,"w") { |f| f.puts YAML.dump(self) }

  end

  def load(para)
    if FileTest.size?(para.step3desfn) != nil
      data = YAML.load_file( para.step3desfn )
      return data
    end
    return nil
  end
  
end
