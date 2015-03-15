module AdtImplementation

  def self.included(mod)
    mod.extend ClassMethods
    mod.send :include, InstanceMethods
  end

  module ClassMethods
    # def adt_methods(*methods)
    #   @adt_methods ||= []
    #   @adt_methods += methods
    # end
    def adt_scheme(scheme_name = nil)
      if scheme_name
        @adt_scheme = Schemes.get(scheme_name)
      else
        fail "Missing scheme for #{self}." unless @adt_scheme
        @adt_scheme
      end
    end

    def prepare(**options)
      Proc.new do
        self.new(options)
      end
    end
  end

  module InstanceMethods
    # def adt_methods
    #   self.class.adt_methods
    # end
    def adt_scheme
      @adt_scheme ||= self.class.adt_scheme.new
    end
  end

end
