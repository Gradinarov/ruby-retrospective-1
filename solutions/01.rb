class Array
  def to_hash ()
    hash = Hash[*self.flatten(1)]
    return hash
  end

  def index_by    
    return self.map{ |i| yield(i) }.zip(self).to_hash
  end
  
  def subarray_count(subarray)
    count = 0
    0.step(self.length, 1) do |i|        
      count += 1 if self.slice(i, subarray.length) == subarray
    end
    return count    
   end

  def occurences_count ()
    hash = Hash.new(0)
    self.each do |i|
      hash[i] += 1
    end
    return hash
  end
end
