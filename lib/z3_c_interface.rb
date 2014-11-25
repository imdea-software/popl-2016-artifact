require 'ffi'
require 'os'

module Z3CInterface
  def self.z3_lib
    ext = OS.windows? ? 'dll' : OS.mac? ? 'dylib' : 'so'
    path = ENV['LIBRARY_PATH'].split(':').find{|p| File.exists?(File.join(p,"libz3.#{ext}"))}
    (log.fatal "Cannot find 'libz3.#{ext}' in \$LIBRARY_PATH."; exit) unless path
    z3 = File.join(path,"libz3.#{ext}")
    log.debug('z3') {"using #{z3}"}
    z3
  end

  def self.extended(mod)
    constants.each do |c|
      val = const_get(c)
      mod.const_set(c,val) if val.is_a?(Class)
    end
  end

  class Configuration < FFI::AutoPointer; def self.release(p) end end
  class Context < FFI::AutoPointer; def self.release(p) end end
  class Parameters < FFI::AutoPointer; def self.release(p) end end
  class ParameterDescriptions < FFI::AutoPointer; def self.release(p) end end
  class Symbol < FFI::AutoPointer; def self.release(p) end end
  class Sort < FFI::AutoPointer; def self.release(p) end end
  class Function < FFI::AutoPointer; def self.release(p) end end
  class Expr < FFI::AutoPointer; def self.release(p) end end
  class Pattern < FFI::AutoPointer; def self.release(p) end end
  class Model < FFI::AutoPointer; def self.release(p) end end
  class Theory < FFI::AutoPointer; def self.release(p) end end
  class FixedPoint < FFI::AutoPointer; def self.release(p) end end
  class ExprVector < FFI::AutoPointer; def self.release(p) end end
  class ExprMap < FFI::AutoPointer; def self.release(p) end end
  class Goal < FFI::AutoPointer; def self.release(p) end end
  class Tactic < FFI::AutoPointer; def self.release(p) end end
  class Probe < FFI::AutoPointer; def self.release(p) end end
  class Solver < FFI::AutoPointer; def self.release(p) end end
  class Statistics < FFI::AutoPointer; def self.release(p) end end
  class RealClosedField < FFI::AutoPointer; def self.release(p) end end


  extend FFI::Library
  ffi_lib z3_lib

  enum :lbool, [:false, -1, :undef, :true]
  enum :symbol_kind, [:int, :string]
  enum :parameter_kind, [:int, :double, :rational, :symbol, :ast, :function]
  enum :sort_kind, [:uninterpreted, :bool, :int, :real, :bv, :array, :datatype, :relation, :finite_domain, :unknown, 1000]
  enum :ast_kind, [:numeral, :app, :var, :quantifier, :sort, :function, :unknown, 1000]
  # TODO enum :decl_kind, [...]
  enum :param_kind, [:unit, :bool, :double, :symbol, :string, :other, :invalid]
  # TODO enum :search_failure, [...]
  # TODO enum :ast_print_mode, [...]
  # TODO enum :error_code, [...]
  # TODO enum Goal_prec, [...]
  typedef :pointer, :string_ptr
  # TODO typedef :error_handler ...
  typedef :int, :bool_opt

  typedef :pointer, :symbol_ary
  typedef :pointer, :ast_ary
  typedef :pointer, :sort_ary
  typedef :pointer, :func_decl_ptr
  typedef :pointer, :func_decl_ary
  typedef :pointer, :pattern_ary

  def self.attach_function(c_name, args, returns)
    ruby_name = c_name.to_s.sub(/Z3_/,"")
    super(ruby_name, c_name, args, returns)
  end

  # Configuration
  attach_function :Z3_global_param_set, [:string, :string], :void
  attach_function :Z3_global_param_reset_all, [], :void
  attach_function :Z3_global_param_get, [:string, :string], :bool

  # Create configuration
  attach_function :Z3_mk_config, [], Configuration
  attach_function :Z3_del_config, [Configuration], :void
  attach_function :Z3_set_param_value, [Configuration, :string, :string], :void

  # Create context
  attach_function :Z3_mk_context, [Configuration], Context
  attach_function :Z3_mk_context_rc, [Configuration], Context
  attach_function :Z3_del_context, [Context], :void
  attach_function :Z3_inc_ref, [Context, Expr], :void
  attach_function :Z3_dec_ref, [Context, Expr], :void
  attach_function :Z3_update_param_value, [Context, :string, :string], :void
  attach_function :Z3_interrupt, [Context], :void

  # Parameters
  attach_function :Z3_mk_params, [Context], Parameters
  attach_function :Z3_params_inc_ref, [Context, Parameters], :void
  attach_function :Z3_params_dec_ref, [Context, Parameters], :void
  attach_function :Z3_params_set_bool, [Context, Parameters, Symbol, :bool], :void
  attach_function :Z3_params_set_uint, [Context, Parameters, Symbol, :uint], :void
  attach_function :Z3_params_set_double, [Context, Parameters, Symbol, :double], :void
  attach_function :Z3_params_set_symbol, [Context, Parameters, Symbol, Symbol], :void
  attach_function :Z3_params_to_string, [Context, Parameters], :string
  attach_function :Z3_params_validate, [Context, Parameters, ParameterDescriptions], :void

  # TODO Parameter Descriptions
  attach_function :Z3_param_descrs_to_string, [Context, ParameterDescriptions], :string

  # Symbols
  attach_function :Z3_mk_int_symbol, [Context, :int], Symbol
  attach_function :Z3_mk_string_symbol, [Context, :string], Symbol
  attach_function :Z3_get_symbol_string, [Context, Symbol], :string

  # Sorts
  attach_function :Z3_mk_uninterpreted_sort, [Context, Symbol], Sort
  attach_function :Z3_mk_bool_sort, [Context], Sort
  attach_function :Z3_mk_int_sort, [Context], Sort
  attach_function :Z3_mk_real_sort, [Context], Sort
  attach_function :Z3_mk_bv_sort, [Context, :uint], Sort
  attach_function :Z3_mk_finite_domain_sort, [Context, Symbol, :uint64], Sort
  attach_function :Z3_mk_array_sort, [Context, Sort, Sort], Sort
  attach_function :Z3_mk_tuple_sort, [Context, Symbol, :uint, :symbol_ary, :sort_ary, :func_decl_ptr, :func_decl_ary], Sort
  # TODO more sorts

  # Constants
  attach_function :Z3_mk_func_decl, [Context, Symbol, :uint, :sort_ary, Sort], Function
  attach_function :Z3_mk_app, [Context, Function, :uint, :ast_ary], Expr
  attach_function :Z3_mk_const, [Context, Symbol, Sort], Expr
  attach_function :Z3_mk_fresh_func_decl, [Context, :string, :uint, :sort_ary, Sort], Function
  attach_function :Z3_mk_fresh_const, [Context, :string, Sort], Expr

  # Propositional Logic and Equality
  attach_function :Z3_mk_true, [Context], Expr
  attach_function :Z3_mk_false, [Context], Expr
  attach_function :Z3_mk_eq, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_distinct, [Context, :uint, :ast_ary], Expr
  attach_function :Z3_mk_not, [Context, Expr], Expr
  attach_function :Z3_mk_ite, [Context, Expr, Expr, Expr], Expr
  attach_function :Z3_mk_iff, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_implies, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_xor, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_and, [Context, :uint, :ast_ary], Expr
  attach_function :Z3_mk_or, [Context, :uint, :ast_ary], Expr

  # Arithmetic: Integers and Reals
  attach_function :Z3_mk_add, [Context, :uint, :ast_ary], Expr
  attach_function :Z3_mk_mul, [Context, :uint, :ast_ary], Expr
  attach_function :Z3_mk_sub, [Context, :uint, :ast_ary], Expr
  attach_function :Z3_mk_unary_minus, [Context, Expr], Expr
  attach_function :Z3_mk_div, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_mod, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_rem, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_power, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_lt, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_le, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_gt, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_ge, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_int2real, [Context, Expr], Expr
  attach_function :Z3_mk_real2int, [Context, Expr], Expr
  attach_function :Z3_mk_is_int, [Context, Expr], Expr

  # Bit-vectors
  attach_function :Z3_mk_bvnot, [Context, Expr], Expr
  attach_function :Z3_mk_bvredand, [Context, Expr], Expr
  attach_function :Z3_mk_bvredor, [Context, Expr], Expr
  attach_function :Z3_mk_bvand, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvor, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvxor, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvnand, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvnor, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvxnor, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvneg, [Context, Expr], Expr
  attach_function :Z3_mk_bvadd, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvsub, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvmul, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvudiv, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvsdiv, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvurem, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvsrem, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvsmod, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvult, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvslt, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvule, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvsle, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvuge, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvsge, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvugt, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvsgt, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_concat, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_extract, [Context, :uint, :uint, Expr], Expr
  attach_function :Z3_mk_sign_ext, [Context, :uint, Expr], Expr
  attach_function :Z3_mk_zero_ext, [Context, :uint, Expr], Expr
  attach_function :Z3_mk_repeat, [Context, :uint, Expr], Expr
  attach_function :Z3_mk_bvshl, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvlshr, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvashr, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_rotate_left, [Context, :uint, Expr], Expr
  attach_function :Z3_mk_rotate_right, [Context, :uint, Expr], Expr
  attach_function :Z3_mk_ext_rotate_left, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_ext_rotate_right, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_int2bv, [Context, :uint, Expr], Expr
  attach_function :Z3_mk_bv2int, [Context, Expr, :bool], Expr
  attach_function :Z3_mk_bvadd_no_overflow,  [Context, Expr, Expr, :bool], Expr
  attach_function :Z3_mk_bvadd_no_underflow, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvsub_no_overflow, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvsub_no_underflow, [Context, Expr, Expr, :bool], Expr
  attach_function :Z3_mk_bvsdiv_no_overflow, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_bvneg_no_overflow,  [Context, Expr], Expr
  attach_function :Z3_mk_bvmul_no_overflow,  [Context, Expr, Expr, :bool], Expr
  attach_function :Z3_mk_bvmul_no_underflow, [Context, Expr, Expr], Expr

  # Arrays
  attach_function :Z3_mk_select, [Context, Expr, Expr], Expr
  attach_function :Z3_mk_store, [Context, Expr, Expr, Expr], Expr
  attach_function :Z3_mk_const_array, [Context, Sort, Expr], Expr
  attach_function :Z3_mk_map, [Context, Function, :uint, :ast_ary], Expr
  attach_function :Z3_mk_array_default, [Context, Expr], Expr

  # TODO Sets

  # Numerals
  attach_function :Z3_mk_numeral, [Context, :string, Sort], Expr
  attach_function :Z3_mk_real, [Context, :int, :int], Expr
  attach_function :Z3_mk_int, [Context, :int, Sort], Expr
  attach_function :Z3_mk_unsigned_int, [Context, :uint, Sort], Expr
  attach_function :Z3_mk_int64, [Context, :int64, Sort], Expr
  attach_function :Z3_mk_unsigned_int64, [Context, :uint64, Sort], Expr

  # Quantifiers
  attach_function :Z3_mk_pattern, [Context, :uint, :ast_ary], Pattern
  attach_function :Z3_mk_bound, [Context, :uint, Sort], Expr
  attach_function :Z3_mk_forall, [Context, :uint, :uint, :pattern_ary, :uint, :sort_ary, :symbol_ary, Expr], Expr
  attach_function :Z3_mk_exists, [Context, :uint, :uint, :pattern_ary, :uint, :sort_ary, :symbol_ary, Expr], Expr
  attach_function :Z3_mk_forall_const, [Context, :uint, :uint, :ast_ary, :uint, :pattern_ary, Expr], Expr
  attach_function :Z3_mk_exists_const, [Context, :uint, :uint, :ast_ary, :uint, :pattern_ary, Expr], Expr
  # TODO many more...

  # TODO Accessors

  # TODO Modifiers
  attach_function :Z3_substitute_vars, [Context, Expr, :uint, :ast_ary], Expr

  # TODO Models

  # Interaction logging
  attach_function :Z3_open_log, [:string], :bool
  attach_function :Z3_append_log, [:string], :void
  attach_function :Z3_close_log, [], :void
  attach_function :Z3_toggle_warning_messages, [:bool], :void

  # String conversion
  attach_function :Z3_ast_to_string, [Context, Expr], :string
  attach_function :Z3_pattern_to_string, [Context, Pattern], :string
  attach_function :Z3_sort_to_string, [Context, Sort], :string
  attach_function :Z3_model_to_string, [Context, Model], :string
  attach_function :Z3_func_decl_to_string, [Context, Function], :string
  # TODO many more...

  # TODO Parser interface
  attach_function :Z3_parse_smtlib2_string, \
    [Context, :string, :uint, :symbol_ary, :sort_ary, :uint, :symbol_ary, :func_decl_ary], \
    Expr
  attach_function :Z3_get_smtlib_error, [Context], :string

  # TODO Error Handling

  # Miscellaneous
  attach_function :Z3_get_version, [:pointer, :pointer, :pointer, :pointer], :void
  # attach_function :Z3_enable_trace, [:string], :void
  # attach_function :Z3_disable_trace, [:string], :void
  attach_function :Z3_reset_memory, [], :void
  # TODO a few more...

  # TODO External Theory Plugins

  # TODO Fixedpoint facilities

  # AST vectors
  attach_function :Z3_ast_vector_to_string, [Context, ExprVector], :string
  # TODO many more..

  # TODO AST maps

  # TODO Goals

  # TODO Tactics and Probes

  # Solvers
  attach_function :Z3_mk_solver, [Context], Solver
  attach_function :Z3_mk_simple_solver, [Context], Solver
  attach_function :Z3_mk_solver_for_logic, [Context, Symbol], Solver
  attach_function :Z3_mk_solver_from_tactic, [Context, Tactic], Solver
  attach_function :Z3_solver_get_help, [Context, Solver], :string
  attach_function :Z3_solver_get_param_descrs, [Context, Solver], ParameterDescriptions
  attach_function :Z3_solver_set_params, [Context, Solver, Parameters], :void
  attach_function :Z3_solver_inc_ref, [Context, Solver], :void
  attach_function :Z3_solver_dec_ref, [Context, Solver], :void
  attach_function :Z3_solver_push, [Context, Solver], :void
  attach_function :Z3_solver_pop, [Context, Solver, :uint], :void
  attach_function :Z3_solver_reset, [Context, Solver], :void
  attach_function :Z3_solver_get_num_scopes, [Context, Solver], :uint
  attach_function :Z3_solver_assert, [Context, Solver, Expr], :void
  # attach_function :Z3_solver_assert_and_track, [Context, Solver, Expr, Expr], :void
  attach_function :Z3_solver_get_assertions, [Context, Solver], ExprVector
  attach_function :Z3_solver_check, [Context, Solver], :lbool
  attach_function :Z3_solver_check_assumptions,  [Context, Solver, :uint, :ast_ary], :lbool
  attach_function :Z3_solver_get_model, [Context, Solver], Model
  attach_function :Z3_solver_get_proof, [Context, Solver], Expr
  attach_function :Z3_solver_get_unsat_core, [Context, Solver], ExprVector
  attach_function :Z3_solver_get_reason_unknown, [Context, Solver], :string
  attach_function :Z3_solver_get_statistics, [Context, Solver], Statistics
  attach_function :Z3_solver_to_string, [Context, Solver], :string

  # TODO Statistics
  attach_function :Z3_stats_to_string, [Context, Statistics], :string

  # TODO Interpolation API
  # TODO Polynomails API
  # TODO Real Closed Fields API

end
