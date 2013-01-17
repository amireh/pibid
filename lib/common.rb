# encoding: UTF-8

require 'addressable/uri'

class String
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