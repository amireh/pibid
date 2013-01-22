helpers do
  def accept_params(attrs, resource)
    raise ArgumentError.new 'No such resource.' if !resource

    p = {}
    attrs.each { |a|
      p[a.to_sym] = params.has_key?(a.to_s) ? params[a] : resource.attribute_get(a)
    }
    p
  end
end