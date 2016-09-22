require "ruby_tools/version"

# module RubyTools
#   # Your code goes here...
# end


Object.class_eval do

  # def to_float
  #   self.to_s.tr(' ','').tr(',','.').to_f
  # end

  def get_caller_name
    a = caller.second.split(':', 2)
    "#{Pathname.new(a.first).basename}, line: #{a.second}" 
  end

  # TODO
  # def presence_if
  #   if block_given?
  #     self if self.present? && yield(self)
  #   else
  #     presence
  #   end
  # end

  def quick_fix(message = nil)
    Rails.logger.debug "\n\nWARNING: quick fix detected in #{get_caller_name}#{message.presence.try {|msq| "\nMESSAGE: #{message}" }}\n\n"
    yield
  end

  # def as
  #   yield(self)
  # end

  # def on(condition)
  #   condition ? yield(self) : self
  #   # yield(self) if condition
  # end

  # zeby nil.to_bool => false
  # chociaz 0.to_bool => true, ale w sumie to Ruby
  def to_bool
    !!self
  end

end


module HashExtensions

  def group_by_values
    group_by {|k, v| v}.compose do |v|
      v.map(&:first)
    end
  end

  # dziala jak map, ale zwraca hash, a nie tablice:
  # x = { "x" => 1, "y" => 2, "z" => 3 }
  # x.hmap { |k,v| { k.to_sym => v.to_s } }
  # => {:x=>"1", :y=>"2", :z=>"3"}
  def hmap(&block)
    Hash[self.map {|k, v| block.call(k,v).to_a.first }]
  end

  # uwaga na hash with_indifferent_access!
  def hmap!(&block)
    replace hmap(&block)
  end

  def compose
    each_with_object({}) do |(k, v), acc|
      acc[k] = yield(v)
      acc
    end
    # hmap {|k,v| {k => yield(v)}} # unikamy zaleznosci od hmap
  end

  def compose!
    each do |k,v|
      self[k] = yield(v)
    end
  end

  def merge(other_hash, options = {})
    return super(other_hash) unless options[:only]

    hash_to_merge = options[:only].hmap {|key| {key => other_hash[key]} }
    hash_to_merge.select! {|key, val| other_hash.has_key? key }
    
    super(hash_to_merge)
  end

  def dig(*keys)
    return self if keys.empty?
    
    ret = self[keys.shift]

    ret.nil? || keys.empty? ? ret : ret.dig(*keys)
  end unless {}.respond_to?(:dig) # dig jest od Ruby 2.3

end

Hash.prepend HashExtensions 

Array.class_eval do
  # [1,2,3].hmap {|el| {el.to_s => 2*el} } # => {"1" => 2, "2" => 4, "3" => 6}
  def hmap(&block)
    Hash[self.map {|k| block.call(k).to_a.first }]
  end
end

Enumerable.module_eval do

  def multiply(identity = 1, nerdy = false, &block)
    unless nerdy
      if block_given?
        map(&block).multiply(identity)
      else
        inject(1.0) {|product, factor| product * factor.to_f} || identity
      end
    else
      2 ** sum {|e| Math.log2(e.to_f) }
    end
  end

end

Proc.class_eval do

  # a = proc {p self}
  # x = a.decorate_with {|&b| p :before; b.call; p :after}.decorate_with {|&b| p :before2; b.call; p :after2}
  # x.call # => :before2 :before main :after :after2
  def decorate_with(&block)
    proc do |*args|
      block.call(*args, &self)
    end
  end

end
