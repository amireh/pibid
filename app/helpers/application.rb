helpers do
  def accept_params(attrs, resource)
    p = {}
    attrs.each { |a|
      p[a.to_sym] = params.has_key?(a.to_s) ? params[a] : resource.attribute_get(a)
    }
    p
  end
end