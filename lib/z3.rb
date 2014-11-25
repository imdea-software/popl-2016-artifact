require 'forwardable'
require_relative 'z3_c_interface'

class Array
  def to_ptr()
    ptr = FFI::MemoryPointer.new(:pointer, count)
    each_with_index do |x,i|
      fail "'#{x.class}' is not a pointer." unless x.is_a?(FFI::Pointer)
      ptr[i].put_pointer(0,x)
    end
    ptr
  end
end

class Symbol
  def to_b()
    case self
    when :true; true
    when :false; false
    else :unknown
    end
  end
end

module Z3
  extend Z3CInterface

  module ContextualObject
    def post_initialize; end
    def cc(context)
      @context = context
      post_initialize
      self
    end
  end

  def self.config()                                   Z3::mk_config() end
  def self.context(config: default_configuration)     
    c = Z3::mk_context(config)
    c.post_initialize
    return c
  end
  def self.context_rc(config: default_configuration)  Z3::mk_context_rc(config) end

  def self.default_configuration; @@default_configuration ||= self.config end
  def self.default_context;       @@default_context ||= self.context      end

  class Configuration 
    def self.release(pointer) Z3::del_config(pointer) end
    def set(param,val) Z3::set_param_value(self, param, val)  end
  end

  class Context
    def post_initialize
      @sorts = {}
      @constants = {}
      @sorts[:bool] = bool_sort
      @sorts[:int] = int_sort
      @sorts[:real] = real_sort
    end
    def self.release(pointer) Z3::del_context(pointer) end

    def resolve(sym)
      @sorts[sym] || @constants[sym] || (fail "Unable to resolve symbol #{sym}.")
    end

    def decl_sort(sym, *args)
      @sorts[sym] = ui_sort(sym)
    end

    def decl_const(sym, *sorts)
      sym = sym.to_sym if sym.respond_to?(:to_sym)
      sorts = sorts.map(&method(:resolve))
      if sorts.count > 1
        @constants[sym] = func_decl(sym, *sorts)
      else
        @constants[sym] = const(sym, sorts.first)
      end
    end

    def inc_ref(expr)     Z3::inc_ref(self,expr) end
    def dec_ref(expr)     Z3::dec_ref(self,expr) end
    def update(param,val) Z3::update_param_value(self, param, val) end
    # def get(param)
    #   ptr = FFI::MemoryPointer.new(:pointer,1)
    #   Z3::get_param_value(self, param, ptr)
    #   str = ptr.read_pointer()
    #   return str.null? ? nil : str.read_string()
    # end
    def interrupt()       Z3::interrupt(self) end

    def parse(str, sorts: @sorts, decls: @constants)
      Z3::parse_smtlib2_string(self, str,
        sorts.count, sorts.map{|n,_| wrap_symbol(n)}.to_ptr, sorts.map{|_,s| s}.to_ptr,
        decls.count, decls.map{|n,_| wrap_symbol(n)}.to_ptr, decls.map{|_,d| d}.to_ptr).
      cc(self)
    end

    def msg; Z3::get_smtlib_error(self) end

    def params; Z3::mk_params(self).cc(self) end

    # TODO ParameterDescriptions

    # Symbols
    def int_symbol(i)     Z3::mk_int_symbol(self,i).cc(self) end
    def string_symbol(s)  Z3::mk_string_symbol(self,s).cc(self) end
    def wrap_symbol(s)
      case s
      when Z3::Symbol; s
      when ::Symbol;   string_symbol(s.to_s)
      when ::String;   string_symbol(s)
      else fail "Unexpected symbol type: #{s.class}"
      end
    end

    # Sorts
    def uninterpreted_sort(sym)
      Z3::mk_uninterpreted_sort(self,wrap_symbol(sym)).cc(self)
    end
    alias :ui_sort :uninterpreted_sort
    def bool_sort;  Z3::mk_bool_sort(self).cc(self) end
    def int_sort;   Z3::mk_int_sort(self).cc(self) end
    def real_sort;  Z3::mk_real_sort(self).cc(self) end

    # Constants
    def func_decl(name, *params, ret)
      Z3::mk_func_decl(self, wrap_symbol(name), params.count, params.to_ptr, ret).cc(self)
    end
    alias :function :func_decl
    def app(decl, *args)    Z3::mk_app(self, decl, args.count, args.to_ptr).cc(self) end
    def const(sym, type)    Z3::mk_const(self, wrap_symbol(sym), type).cc(self) end
    def int(num, type: nil) Z3::mk_int(self, num, type || @sorts[:int]).cc(self) end

    def expr(expr, *args)
      expr = expr.to_sym if expr.is_a?(String)
      case expr
      when Fixnum
        int(expr)
      when ::Symbol
        if args.empty?
          resolve(expr)
        else
          decl = resolve(expr)
          fail "XXX" unless decl && decl.is_a?(Function)
          app(decl, *args)
        end
      else
        fail "Unexpected expression: #{expr} of #{expr.class}."
      end
    end

    # Propositional Logic and Equality, Arithmetic: Integers and Reals
    [:true, :false, :eq, :not, :ite, :iff, :implies, :xor,
     :unary_minus, :div, :mod, :rem, :power, :lt, :le, :gt, :ge,
     :int2real, :real2int, :is_int].each do |f|
      define_method(f) do |*args|
        Kernel.const_get(:Z3).method("mk_#{f}").call(self,*args).cc(self)
      end
    end
    [:distinct, :and, :or, :add, :mul, :sub].each do |f|
      define_method(f) do |*args|
        Kernel.const_get(:Z3).method("mk_#{f}").call(self,args.count,args.to_ptr).cc(self)
      end
    end
    alias :tt :true
    alias :ff :false
    alias :conj :and
    alias :disj :or

    # Quantifiers
    def pattern(*exprs) Z3::mk_pattern(self,exprs.count,exprs.to_ptr).cc(self) end
    def bound(idx, ty) Z3::mk_bound(self,idx,ty).cc(self) end

    [:forall, :exists].each do |f|
      define_method(f) do |*vars, body, weight:0, patterns:[]|
        Kernel.const_get(:Z3).method("mk_#{f}_const").
          call(self,weight,vars.count,vars.to_ptr,patterns.count,patterns.to_ptr,body).cc(self)
      end
    end

    # Solvers
    def solver; Z3::mk_solver(self).cc(self) end
    def simple_solver; Z3::mk_simple_solver(self).cc(self) end
  end

  class Parameters 
    include ContextualObject
    def post_initialize
      inc_ref
    end
    def self.release(pointer)
      pointer.dec_ref
    end
    def inc_ref; Z3::params_inc_ref(@context,self) end
    def dec_ref; Z3::params_dec_ref(@context,self) end
    def set(str,val)
      sym = @context.string_symbol(str)
      if val.is_a?(TrueClass) || val.is_a?(FalseClass)
        Z3::params_set_bool(@context,self,sym,val)
      elsif val.is_a?(Fixnum)
        Z3::params_set_uint(@context,self,sym,val)
      elsif val.is_a?(Float)
        Z3::params_set_double(@context,self,sym,val)
      else
        Z3::params_set_symbol(@context,self,sym,val)
      end
    end
    def to_s; Z3::params_to_string(@context,self) end
    def validate(descriptors); Z3::params_validate(@context,self,descriptors) end
  end

  class ParameterDescriptions 
    include ContextualObject
    def self.release(pointer) end
    def to_s; Z3::param_descrs_to_string(@context,self) end
  end

  class Symbol 
    include ContextualObject
    def self.release(pointer) end
    def to_s; Z3::get_symbol_string(@context,self) end
  end

  class Sort 
    include ContextualObject
    def self.release(pointer) end
    def to_s; Z3::sort_to_string(@context, self) end
  end

  class Function 
    include ContextualObject
    def post_initialize
    end
    def self.release(pointer) end
    def app(*args)  @context.app(self,*args) end
    def to_s;       Z3::func_decl_to_string(@context, self) end
  end

  class Expr 
    include ContextualObject
    def self.release(pointer) end
    [:eq, :not, :iff, :implies, :and, :or, :xor,
     :unary_minus, :add, :sub, :mul, :div, :mod, :rem, :power,
     :lt, :le, :gt, :ge].each do |f|
       define_method(f) do |*args|
         @context.send(f, self, *args)
       end
    end
    def to_s; Z3::ast_to_string(@context, self) end

    def substitute_vars(exprs)
      puts "Substituting #{exprs} in #{self}"
      Z3::substitute_vars(@context, self, exprs.count, exprs.to_ptr)
      self
    end

    alias :conj :and
    alias :disj :or

    def ==(e)  eq(e) end
    def ===(e) iff(e) end
    def !;     send(:not) end
    def !=(e)  !(eq(e)) end
    def ^;     xor(e) end
    def -@;    unary_minus end
    def /(e)   div(e) end
    def %(e)   mod(e) end
    def **(e)  power(e) end
    def <(e)   lt(e) end
    def <=(e)  le(e) end
    def >(e)   gt(e) end
    def >=(e)  ge(e) end
    def &(e)   send(:and,e) end
    def |(e)   send(:or,e) end
    def +(e)   add(e) end
    def *(e)   mul(e) end
    def -(e)   sub(e) end
  end

  class Pattern
    include ContextualObject
    def self.release(pointer) end
    def to_s
      Z3::pattern_to_string(@context,self)
    end
  end

  class Model 
    include ContextualObject
    def self.release(pointer) end
    def to_s
      Z3::model_to_string(@context,self)
    end
  end

  class Theory 
    def self.release(pointer) end
  end

  class FixedPoint 
    def self.release(pointer) end
  end

  class ExprVector 
    def self.release(pointer) end
  end

  class ExprMap 
    def self.release(pointer) end
  end

  class Goal 
    def self.release(pointer) end
  end

  class Tactic 
    def self.release(pointer) end
  end

  class Probe 
    def self.release(pointer) end
  end

  class Solver 
    include ContextualObject

    extend Forwardable
    def_delegators :@context, :inc_ref, :dec_ref
    def_delegators :@context, :parse, :msg
    def_delegators :@context, :int_symbol, :string_symbol
    def_delegators :@context, :ui_sort, :bool_sort, :int_sort, :real_sort
    def_delegators :@context, :func_decl, :function, :app, :const, :int
    def_delegators :@context, :true, :false, :eq, :not, :and, :or, :xor, :ite, :iff, :implies
    def_delegators :@context, :unary_minus, :add, :sub, :mul, :div, :mod, :rem, :power
    def_delegators :@context, :distinct
    def_delegators :@context, :lt, :le, :gt, :ge
    def_delegators :@context, :int2real, :real2int, :is_int
    def_delegators :@context, :forall, :exists

    def post_initialize
      inc_ref
    end
    def self.release(pointer)
      pointer.dec_ref
    end

    def help; Z3::solver_get_help(@context,self) end
    def param_descrs; Z3::solver_get_param_descrs(@context,self).cc(@context) end

    def set_params(ps)
      log.debug('z3') {"setting parameters: #{ps}"}
      Z3::solver_set_params(@context,self,ps)
    end
    def inc_ref; Z3::solver_inc_ref(@context,self) end
    def dec_ref; Z3::solver_dec_ref(@context,self) end
    def stats; Z3::solver_get_statistics(@context,self).cc(@context) end
    def to_s;  Z3::solver_to_string(@context,self) end

    def push()
      log.debug('z3') {"push"}
      Z3::solver_push(@context,self)
    end

    def pop(level: 1)
      log.debug('z3') {"pop(#{level})"}
      Z3::solver_pop(@context,self,level)
    end

    def reset()
      log.debug('z3') {"reset"}
      Z3::solver_reset(@context,self)
    end

    def assert(expr)
      expr = @context.parse("(assert #{expr})") if expr.is_a?(String)
      fail "Unexpected expression type #{expr.class}" unless expr.is_a?(Expr)
      log.debug('z3') {"assert #{expr}"}
      Z3::solver_assert(@context,self,expr)
    end

    def check
      res = Z3::solver_check(@context,self).to_b
      case res
      when true;  log.debug('z3') {"sat\n#{model}"}
      when false; log.debug('z3') {"unsat"}
      else        log.debug('z3') {"unknown"}
      end
      log.debug('z3') {"statistics\n#{stats}"}
      res
    end

    def model; Z3::solver_get_model(@context,self).cc(@context) end
    def proof; Z3::solver_get_proof(@context,self).cc(@context) end
  end

  class Statistics 
    include ContextualObject
    def self.release(pointer) end
    def to_s; Z3::stats_to_string(@context,self) end
  end

  class RealClosedField 
    def self.release(pointer) end
  end

end
