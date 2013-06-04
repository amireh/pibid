require 'dm-core'
require 'dm-types'

module DataMapper
  module Is
    module Journallable

      def is_journallable(options = {})
        extend ClassMethods
      end

      module ClassMethods
        # attr_accessor :shadows

        def get(*key)
          # puts '>> Model#get <<'

          if r = shadow_get(key)
            return r
          end

          super(key)
        end

        def shadow(key, model)
          # puts ">> Shadowing #{model.id} with #{key} <<"
          @@shadows      ||= {}
          @@shadows[key.to_s] = model
        end

        def shadow_get(*key)
          @@shadows ||= {}

          # puts ">> Looking up a shadow for #{key}"
          # puts ">> Shadow map: %s" %[self.shadows.map { |e,v| "#{e} => #{v.id}" }]

          @@shadows[key.flatten.first.to_s]
        end

        def shadows
          @@shadows ||= {}
        end
      end
    end
  end

  Model.append_extensions(Is::Journallable)
end