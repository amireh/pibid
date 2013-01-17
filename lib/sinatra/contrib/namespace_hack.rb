module Sinatra
  module NamespaceHack
    # makes it possible to invoke the `namespace` method provided by Sinatra::Namespace
    # as `route_namespace` to avoid conflicts with rake's `namespace()` definition
    def route_namespace(pattern, conditions = {}, &block)
      self.namespace(pattern, conditions, &block)
    end
  end

  register NamespaceHack
end