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

  def is_email?(s)
    (s =~ /^[a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/u) != nil
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
  def pibi_to_datetime(graceful = true)
    m,d,y = self.split(/\/|\-/)
    begin
      DateTime.new(y.to_i,m.to_i,d.to_i)
    rescue ArgumentError => e
      raise e unless graceful
      DateTime.now
    end
  end
end

class Fixnum
  def pibi_to_datetime(graceful = true)
    begin
      Time.at(self).to_datetime
    rescue RuntimeError => e
      raise e unless graceful
      DateTime.now
    end
  end
end

class Object
  def pibi_to_datetime(*args)
    if self.is_a?(String) || self.is_a?(Fixnum)
      super(*args)
    elsif self.is_a?(Float)
      self.to_i.pibi_to_datetime(*args)
    else
      self.to_s.pibi_to_datetime(*args)
    end
  end
end