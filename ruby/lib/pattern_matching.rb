class PatternFound < Exception
end

class PatternNotFound < Exception
end

class Object
  # Dos alternativas para matches? son:
  # -Hacerlo un metodo de clase de PatternMatching (ver rama no_extra_monkey para esto)
  # -Colocar en un module para que se incluya al nivel que el usuario quiera usarlo
  def matches?(obj, &b)
    inst_pttrn_mtc = PatternMatching.new obj
    begin
      inst_pttrn_mtc.instance_eval &b
    rescue PatternFound
      inst_pttrn_mtc.ret
    else
      raise PatternNotFound, "Reached end of pattern matching block"
    end
  end
end

class PatternMatching

  attr_reader :ret

  def initialize(obj)
    @obj = obj
  end

  def val(a_value)
    BasicMatcher.new { |obj| obj == a_value}
  end

  def type(a_type)
    BasicMatcher.new { |obj| obj.is_a? a_type}
  end

  def duck(*methods)
    BasicMatcher.new { |obj| methods.all? { |method| obj.methods.include? method} }
  end

  def list(a_list, match_size = true) #No me deja ponerle el ? a match_size? -- Mati
    ListMatcher.new a_list, match_size
  end

  def with(*matchers, &b)
    if matchers.all? { |matcher| matcher.call @obj }
      matchers.each { |matcher| matcher.do_bindings @obj, self }
      @ret = self.instance_eval &b
      raise PatternFound

      # TODO detalle: la excepción puede llevarse datos y de esa manera evitan tener que guardar
      #   el valor como estado interno del matching
      #
      # [11] pry(main)> class C < Exception
      # [11] pry(main)*   def initialize(counter)
      # [11] pry(main)*     @counter = counter
      # [11] pry(main)*   end
      # [11] pry(main)*   def counter
      # [11] pry(main)*     @counter
      # [11] pry(main)*   end
      # [11] pry(main)* end
      # [13] pry(main)> begin
      # [13] pry(main)*   raise C.new(122)
      # [13] pry(main)* rescue C => ccc
      # [13] pry(main)*   ccc.counter
      # [13] pry(main)* end
      # => 122
    end
  end

  def otherwise(&b)
    @ret = self.instance_eval &b
    raise PatternFound
  end
end

#Composite Pattern

module Matcher
  def and(*matchers)
    matchers.push self
    AndMatcher.new matchers
  end

  def or(*matchers)
    matchers.push self
    OrMatcher.new matchers
  end

  def not
    NotMatcher.new self
  end
end

class ComplexMatcher
  include Matcher

  def initialize(children)
    @children = children
  end

  def do_bindings(obj, pttrn_mtc)
    @children.each { |child| child.do_bindings(obj, pttrn_mtc) if binding_condition(child, obj)}
  end
end

class AndMatcher < ComplexMatcher
  def call(obj)
    @children.all? { |child| child.call(obj) }
  end

  def binding_condition(_child, _obj)
    true
  end
end

class OrMatcher < ComplexMatcher
  def call(obj)
    @children.any? { |child| child.call(obj) }
  end

  def binding_condition(child, obj)
    child.call(obj)
  end
end

class NotMatcher
  include Matcher

  def initialize(child)
    @child = child
  end

  def call(obj)
    not @child.call(obj)
  end

  def do_bindings(obj, pttrn_mtc)
    @child.do_bindings obj, pttrn_mtc
  end
end

class ListMatcher
  include Matcher

  def initialize(patterns, matches_size)
    @patterns = patterns
    @matches_size = matches_size
  end

  def call(obj)
    obj.is_a? Array and (not @matches_size or @patterns.length == obj.length) and self.list_matches? obj
  end

  def do_bindings(list, pttrn_mtc)
    #Se puede modificar para que zippee los array en lugar de usar un indice
    @patterns.each_index do |index|
      @patterns[index].do_bindings(list[index], pttrn_mtc) if @patterns[index].is_a? Matcher
    end
  end

  def list_matches?(list)
    index = -1
    @patterns.all? do |pattern|
      index += 1
      if list.length <= index
        true
      elsif pattern.is_a? Matcher
        pattern.call(list[index])
      else
        pattern == list[index]
      end
    end
  end
end

#Leaf classes
class BasicMatcher
  include Matcher

  def initialize(&block)
    @block = block
  end

  def call(obj)
    @block.call obj
  end

  def do_bindings(_obj, _pttrn_mtc)
  end
end

class Symbol
  include Matcher

  def call(_obj)
    true
  end

  def do_bindings(obj, pttrn_mtc)
    pttrn_mtc.define_singleton_method(self) { obj }
  end
end
