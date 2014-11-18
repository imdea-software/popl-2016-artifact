require 'ffi'
require 'os'

class ScalObject

  module CAPI
    extend FFI::Library
    def self.scal_lib
      ext = OS.windows? ? 'dll' : OS.mac? ? 'dylib' : 'so'
      path = ENV['LIBRARY_PATH'].split(':').find{|p| File.exists?(File.join(p,"libscal.#{ext}"))}
      (log.fatal "Cannot find 'libscal.#{ext}' in \$LIBRARY_PATH."; exit) unless path
      File.join(path,"libscal.#{ext}")
    end
    ffi_lib scal_lib
    attach_function :scal_initialize, [:uint], :void
    attach_function :scal_object_create, [:string], :pointer
    attach_function :scal_object_name, [:string], :string
    attach_function :scal_object_spec, [:string], :string
    attach_function :scal_object_put, [:pointer, :int], :void
    attach_function :scal_object_get, [:pointer], :int
  end

  CAPI::scal_initialize(8)

  def initialize(object_id)
    @id = object_id
    @object = CAPI::scal_object_create(@id)
    @gen = Random.new
  end

  def self.spec; CAPI::scal_object_spec(@id) end
  def to_s; CAPI::scal_object_name(@id) end

  def add(val)
    Thread.pass
    CAPI::scal_object_put(@object,val)
    Thread.pass
    nil
  end

  def remove
    Thread.pass
    val = CAPI::scal_object_get(@object)
    Thread.pass
    return val == -1 ? :empty : val
  end
end