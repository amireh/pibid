module DataMapper
  module Resource
    def all_errors
      errors.map { |e| e.first }
    end

    def refresh
      self.class.get(self.id)
    end
  end
end
