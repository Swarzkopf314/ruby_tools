require "ruby_tools/version"

# module RubyTools
#   # Your code goes here...
# end

module Helper

  # http://ruby-doc.org/core-2.2.0/Binding.html
  # to zwraca hasha ze wszystkimi zmiennymi lokalnymi i ich wartościami w przekazanym context (przez wywołanie binding);
  # czyli należy wywoływać przez: AppHelper.local_variables_hash(binding) 
  def self.local_variables_hash(context)
    context.eval <<-RUBY, __FILE__, __LINE__
      (local_variables | [:self]).hmap do |v| 
        { 
          v => eval(v.to_s).instance_eval {is_a?(ActiveRecord::Base) ? inspect : to_s}[0..500] 
        }
      end
    RUBY
  end if false # TODO AppHelper?

  # TODO - zamienic key na path = [] ?
  def self.traverse(object, key = nil)
    case object
      when Hash
        object.each {|k, v| traverse(v, "#{key}.#{k}", &Proc.new) }
      when Array
        object.each_with_index {|el, index| traverse(el, "#{key}[#{index}]", &Proc.new) }
      else
        yield object, key
    end

    object
  end

  # TODO - zamienic key na path = [] ?
  def self.map_traverse(object, key: nil, transform_hash_key: nil)
    case object
      when Hash
        object.hmap {|k, v| {(transform_hash_key.nil? ? k : transform_hash_key[k]) => map_traverse(v, key: "#{key}.#{k}", transform_hash_key: transform_hash_key, &Proc.new)} }
      when Array
        object.each_with_index.map {|el, index| map_traverse(el, key: "#{key}[#{index}]", transform_hash_key: transform_hash_key, &Proc.new) }
      else
        yield object, key
    end
  end

  # caching proc
  def self.rounding_hash(precision = 2)
    # TODO - round price
    Hash.new {|this, key| this[key] = self.round_price(key, precision) }
  end
  
  def self.assertion_proc
    prc = block_given? ? Proc.new : proc {|msg| raise msg} 

    return proc {|cond, msg = "assertion_failed"| prc.call(msg) unless cond}
  end

end


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

  def tap_in_block_if(condition)
    condition ? yield(self) : self
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
      acc[k] = yield(v, k)
      acc
    end
    # hmap {|k,v| {k => yield(v)}} # unikamy zaleznosci od hmap
  end

  def compose!
    each do |k,v|
      self[k] = yield(v, k)
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

String.class_eval do

  def is_number?
    to_i.to_s == self.strip || to_f.to_s == self.strip
  end

end