require 'addressable/uri'

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

class Hash
  # Removes a key from the hash and returns the hash
  def delete!(key)
    self.delete(key)
    self
  end

  # Merges self with another hash, recursively.
  #
  # This code was lovingly stolen from some random gem:
  # http://gemjack.com/gems/tartan-0.1.1/classes/Hash.html
  #
  # Thanks to whoever made it.
  def deep_merge(hash)
    target = dup

    hash.keys.each do |key|
      if hash[key].is_a? Hash and self[key].is_a? Hash
        target[key] = target[key].deep_merge(hash[key])
        next
      end

      target[key] = hash[key]
    end

    target
  end
end

class String
  Vowels = ['a','o','u','i','e']
  def vowelize
    Vowels.include?(self[0]) ? "an #{self}" : "a #{self}"
  end

  def to_plural
    DataMapper::Inflector.pluralize(self)
  end

  def pluralize(n = nil, with_adverb = false)
    plural = to_plural
    n && n != 1 ? "#{with_adverb ? 'are ' : ''}#{n} #{plural}" : "#{with_adverb ? 'is ' : ''}1 #{self}"
  end

  def sanitize
    Addressable::URI.parse(self.downcase.gsub(/[[:^word:]]/u,'-').squeeze('-').chomp('-')).normalized_path
  end

  # expected format: "MM/DD/YYYY"
  def to_date(graceful = true)
    m,d,y = self.split(/\/|\-/)
    begin
      DateTime.new(y.to_i,m.to_i,d.to_i)
    rescue ArgumentError => e
      raise e unless graceful
      DateTime.now
    end
  end
end

