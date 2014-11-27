require 'ffi'
require 'os'

class ScalObject

  module CAPI
    extend FFI::Library
    def self.scal_lib
      ext = OS.windows? ? 'dll' : OS.mac? ? 'dylib' : 'so'
      path = ENV['LIBRARY_PATH'].split(':').find{|p| File.exists?(File.join(p,"libscal.#{ext}"))}
      fail "Cannot find 'libscal.#{ext}' in \$LIBRARY_PATH." unless path
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

  CAPI::scal_initialize(20)
  @@spec = "???"

  def initialize(object_id)
    @id = object_id
    @object = CAPI::scal_object_create(@id)
    @name = CAPI::scal_object_name(@id) # TODO why does this need a warm-up?
    @name = CAPI::scal_object_name(@id)
    @@spec = CAPI::scal_object_spec(@id)
    @gen = Random.new
  end

  def self.spec; @@spec end
  def to_s; CAPI::scal_object_name(@id) end

  def add(val)
    CAPI::scal_object_put(@object,val)
    nil
  end

  def remove
    val = CAPI::scal_object_get(@object)
    return val == -1 ? :empty : val
  end
end