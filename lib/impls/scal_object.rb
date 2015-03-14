require 'ffi'
require 'os'

class ScalObject < FFI::AutoPointer; def self.release(p) end end

class ScalObject
  include AdtImplementation
  adt_scheme :collection

  PASS_BOUND = 3

  module CAPI
    extend FFI::Library
    def self.scal_lib
      ext = OS.windows? ? 'dll' : OS.mac? ? 'dylib' : 'so'
      path = ENV['LIBRARY_PATH'].split(':').find{|p| File.exists?(File.join(p,"libscal.#{ext}"))}
      fail "Cannot find 'libscal.#{ext}' in \$LIBRARY_PATH." unless path
      File.join(path,"libscal.#{ext}")
    end
    ffi_lib scal_lib
    attach_function :scal_object_name, [:string], :string
    attach_function :scal_object_spec, [:string], :string

    attach_function :scal_initialize, [:uint], :void

    attach_function :scal_object_create, [:string], ScalObject
    attach_function :scal_object_delete, [ScalObject], :void
    attach_function :scal_object_put, [ScalObject, :int], :void
    attach_function :scal_object_get, [ScalObject], :int
  end

  @@spec = "???"

  def self.initialize(num_threads) CAPI::scal_initialize(num_threads) end
  def self.create(id)
    obj = CAPI::scal_object_create(id)
    obj.send(:post_initialize,id)
    obj
  end
  def self.release(pointer) CAPI::scal_object_delete(pointer) end
  def self.spec; @@spec end

  def post_initialize(object_id)
    @id = object_id
    @name = CAPI::scal_object_name(@id) # TODO why does this need a warm-up?
    @name = CAPI::scal_object_name(@id)
    @@spec = CAPI::scal_object_spec(@id)
    @gen = Random.new
  end
  private :post_initialize

  def to_s; CAPI::scal_object_name(@id) end

  def add(val)
    CAPI::scal_object_put(self,val)
    nil
  end

  def remove
    val = CAPI::scal_object_get(self)
    return val == -1 ? :empty : val
  end

end