module DataMapper
  class Collection < LazyArray
    alias_method :__get, :get

    def get(*key)
      if model.respond_to?(:shadow)
        if r = model.shadow_get(*key)
          return r
        end
      end

      __get(*key)
    end

  end
end