class LazyObject < Delegator

  def initialize(&block)
    @block, @loaded = block, false
  end

  def __getobj__
    return @object if @loaded
    @loaded = true
    @object = @block.call
  end

end