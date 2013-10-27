require 'addressable/uri'

helpers do
  def is_email?(s)
    (s =~ /^[a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/u) != nil
  end

  # expected format: "MM/DD/YYYY"
  def parse_date(date_string)
    date_string ||= ''

    unless date_string =~ /(\d{1,2})\/(\d{1,2})\/(\d{4,})/
      return false
    end

    m, d, y = $1, $2, $3

    begin
      Time.utc(y, m, d)
    rescue ArgumentError => e
      return false
    end
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

  alias_method :pluralize, :to_plural

  def sanitize
    Addressable::URI.parse(self.downcase.gsub(/[[:^word:]]/u,'-').squeeze('-').chomp('-')).normalized_path
  end
end