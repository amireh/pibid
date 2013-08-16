module DataMapper
  module Validations
    class ValidationErrors
      def to_json(ctx = nil)
        self.to_hash.to_json
      end
    end
  end

  module Resource
    def all_errors
      errors.map(&:first).flatten
    end
    alias_method :collect_errors, :all_errors

    def refresh
      self.class.get(self.id)
    end

    def report_errors
      self.errors.to_json
    end
  end
end
