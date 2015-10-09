require 'ffi'
require 'os'

class ScalImpl < FFI::AutoPointer
  def self.release(pointer)
  end

  module CAPI
    extend FFI::Library
    def self.scal_lib
      ext = OS.windows? ? 'dll' : OS.mac? ? 'dylib' : 'so'
      fail "$LIBRARY_PATH is not set." unless ENV['LIBRARY_PATH']
      path = ENV['LIBRARY_PATH'].split(':').find{|p| File.exists?(File.join(p,"libscal.#{ext}"))}
      fail "Cannot find 'libscal.#{ext}' in \$LIBRARY_PATH." unless path
      File.join(path,"libscal.#{ext}")
    end
    ffi_lib scal_lib
    attach_function :scal_object_name, [:string], :string
    attach_function :scal_object_spec, [:string], :string

    attach_function :scal_initialize, [:uint], :void

    attach_function :scal_object_create, [:string], ScalImpl
    attach_function :scal_object_delete, [ScalImpl], :void
    attach_function :scal_object_put, [ScalImpl, :int], :void
    attach_function :scal_object_get, [ScalImpl], :int
  end

  def self.release(pointer)
    CAPI::scal_object_delete(pointer)
  end

end

class ScalObject
  include AdtImplementation
  adt_scheme :collection

  def self.prepare(**options)
    ScalImpl::CAPI::scal_initialize(options[:num_threads]||1)
    Proc.new do
      self.new(options)
    end
  end

  def initialize(id: :msq)
    @id = id
    ScalImpl::CAPI::scal_object_name(@id.to_s) # FIXME this is a warmup
    @impl = ScalImpl::CAPI::scal_object_create(id.to_s)
  end

  def to_s
    ScalImpl::CAPI::scal_object_name(@id.to_s)
  end

  def add(val)
    ScalImpl::CAPI::scal_object_put(@impl,val)
    nil
  end

  def remove
    val = ScalImpl::CAPI::scal_object_get(@impl)
    return val == -1 ? :empty : val
  end

end
