require 'bigdecimal'
require 'bigdecimal/util'
module Help_methods
  def help(key, value)
    str = ""
    if key.promotion[:get_one_free] != nil
      sum = sprintf("%5.2f", key.get_one_free(value, 0))
      get = key.promotion.values[0] - 1
      str = "|   (buy #{get}, get 1 free)"+" "*(27 - get.to_s.length)
      str += "|" + " "*(9 - sum.length) + "#{"%5.2f"%sum} |\n"
    end
    return str
  end

  def help2(key, value)
    if key.promotion[:package] != nil
      sum = sprintf("%5.2f", key.package(value, 0))
      get, num=key.promotion[:package].values[0],key.promotion[:package].keys[0]
      length, num_length = get.to_s.length, num.to_s.length
      str = "|   (get #{get}% off for every #{num})"+" "*(23-length-num_length)
      return str += "|" + " "*(9 - sum.length) + "#{"%5.2f"%sum} |\n"
    end
    return ""
  end

  def ordinalize(number)
    if (10...20).include?(number)
      return "#{number}th"
    else
      arr = %w{ th st nd rd th th th th th th }
      return number.to_s + arr[number%10]
    end
  end

  def help3(key, value)
    if key.promotion[:threshold] != nil
      get = key.promotion[:threshold].values[0]
      sum, len = sprintf("%5.2f", key.threshold(value, 0)), get.to_s.length
      th = ordinalize(key.promotion[:threshold].keys[0])
      str = "|   (#{get}% off of every after the #{th})"+" "*(18-len-th.length)
      return str += "|" + " "*(9 - sum.length) + "#{"%5.2f"%sum} |\n"
    end
    return ""
  end

  def gte_zero (number) #greather than or equal to
    if number < "0.00".to_d
      number = "0.00".to_d
    end
    return number
  end
end

class Product
  attr_accessor :name, :price, :promotion
  def initialize(name = "", price = "0.00", promotion = {})
    @name = name
    @price = BigDecimal(price)
    @promotion = promotion
  end
  
  def get_one_free(qty, sum)
    get_one_free = self.promotion[:get_one_free]
    if (get_one_free != nil && qty >= get_one_free)
      sum -= (qty / self.promotion[:get_one_free])*self.price
    end
    return sum
  end
  
  def package(qty, sum)
    if (self.promotion[:package]!=nil && qty>=self.promotion[:package].keys[0])
      key = self.promotion[:package].keys[0]
      value = self.promotion[:package].values[0]
      sum = sum - (qty - qty%key)*self.price*(value/100.0)
    end
    return sum
  end
  
  def threshold(qty, sum)
    threshold = self.promotion[:threshold]
    if (threshold != nil && qty >= threshold.keys[0])
      key = self.promotion[:threshold].keys[0]
      value = self.promotion[:threshold].values[0]
      sum = sum - (qty - key)*self.price*(value/100.0)
    end
    return sum
  end
end

class Coupon
  attr_accessor :name, :type
  def initialize(name, type)
    @name = name
    @type = type
  end
end
class Inventory
  attr_accessor :inventory, :coupons
  def initialize
    @inventory = []
    @coupons = []
  end
  
  def register(name, price, promotion={})
    if name.length>40 || price.to_d<=("0.00").to_d || price.to_d>("999.99").to_d
      raise "Invalid parameters passed."
    end
    if self.inventory.any?{ |product| product.name == name }
      raise "Invalid parameters passed."
    end
    product = Product.new(name, price, promotion)
    @inventory << product
  end
  
  def register_coupon(name, type)
    coupon = Coupon.new(name, type)
    @coupons << coupon
  end
  
  def new_cart
    cart = Cart.new(self.inventory, self.coupons)
    return cart
  end
end

class Cart
  include Help_methods
  attr_accessor :inventory, :purchase, :coupons, :coupons_used
  def initialize(inventory, coupons)
    @inventory = inventory
    @coupons = coupons
    @purchase = {}
    @coupons_used = []
  end
  
  def add(name_of_product, quantity = 1)
    raise "Invalid parameters passed." if quantity <= 0 || quantity > 99
    if @inventory.none? { |product| product.name == name_of_product }
      raise "Invalid parameters passed."
    end
    key = @inventory.select{ |product| product.name == name_of_product }.first
    @purchase[key] += quantity and return if @purchase.has_key?(key)
    product = @inventory.select { |n| n.name == name_of_product }.first
    @purchase.merge!(product => quantity) 
  end
  
  def use(name_of_coupon)
    if self.coupons.none?{ |coupon| coupon.name == name_of_coupon }
      raise "Invalid parameters passed."
    end
    raise "Invalid parameters passed." if @coupons_used != []
    coupon = @coupons.select { |iter| iter.name == name_of_coupon }.first
    @coupons_used << coupon
  end
  
  def coupon(sum)
    return sum if @coupons_used == []        
    type = @coupons_used[0].type        
    sum -= (type.values[0]/100.0)*sum if type.keys[0] == :percent    
    sum -= type.values[0].to_d if type.keys[0] == :amount
    return sum
  end
  
  def total
    sum = "0.00".to_d
    @purchase.each do |key, value|
      sum += value*key.price
      sum = key.get_one_free(value, sum)
      sum = key.package(value, sum)
      sum = key.threshold(value, sum)    
    end
    return gte_zero(self.coupon(sum))
  end
  
  def invoice
    Printer.new(inventory, coupons, purchase, coupons_used).print
  end  
  
end

class Printer < Cart
  def initialize(inventory, coupons, purchase, coupons_used)
    @inventory = inventory
    @coupons = coupons
    @purchase = purchase
    @coupons_used = coupons_used
  end
  
  def print
    str = "+------------------------------------------------+----------+\n"
    str1 = "| Name                                       qty |    price |\n"
    total = sprintf("%5.2f", self.total)
    str2 = "| TOTAL" + " "*42 + "|" + " "*(9 - total.length)+ "#{total} |\n"
    head = str + str1 + str
    tail = str + str2 + str
    head + self.body + self.coupon_percent + self.coupon_amount + tail
  end
  
  def coupon_percent
    return "" if @coupons_used == [] || @coupons_used[0].type.keys[0]!=:percent
    name, percent = @coupons_used[0].name, @coupons_used[0].type.values[0]
    sum = sprintf("%5.2f",-(self.without_coupons-coupon(self.without_coupons)))
    len = percent.to_s.length
    str = "| Coupon #{name} - #{percent}% off"+" "*(32 - name.length-len)
    return str += "|" + " "*(9-sum.to_s.length) + "#{"%5.2f"%sum} |\n"      
  end
  
  def coupon_amount
    return "" if @coupons_used == [] || @coupons_used[0].type.keys[0] != :amount
    name, num = @coupons_used[0].name, @coupons_used[0].type.values[0]
    sum = sprintf("%5.2f",-(self.without_coupons - self.total))
    len = num.to_s.length
    str = "| Coupon #{name} - #{"%5.2f"%num} off"+" "*(33-name.length-len)
    return str += "|" + " "*(9-sum.to_s.length) + "#{"%5.2f"%sum} |\n"    
  end
  
  def body
    str = ""
    @purchase.each do |k, v|
      qty, val = sprintf("%5.0f", v), sprintf("%5.2f", k.price*v) 
      len = k.name.length
      str += "| #{k.name}"+" "*(46-len-qty.length)+"#{qty} |"+" "*(9-val.length)
      str += "#{val} |\n" + help(k, v) + help2(k, v) + help3(k, v)
    end
    return str
  end
  
  def without_coupons
    sum = "0.00".to_d
    @purchase.each do |key, value|
      sum += value*key.price
      sum = key.get_one_free(value, sum)
      sum = key.package(value, sum)
      sum = key.threshold(value, sum)    
    end
    return sum
  end
end