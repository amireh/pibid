def validate_journal_entries(entries, required_keys)
  unless entries.is_a?(Array)
    halt 400, "Malformed journal structure: entry listing must be an array, got #{entries.class.name}"
  end

  entries.each do |entry|
    unless entry.is_a?(Hash)
      halt 400, "Malformed journal structure: expected entry to be a Hash, got #{entry.class.name}"
    end

    required_keys.each do |key|
      return "Missing required entry data '#{key}'" if !entry.has_key?(key)
    end

    # Resolve the scope
    if required_keys.include?('scope')
      scope = entry['scope'].split(':')
      scope, collection = scope.first, scope.last

      resolved_scope, resolved_collection = nil, nil
      coll_key = "@#{scope}_#{collection}".to_sym

      # have we resolved it in an earlier entry?
      unless resolved_scope = instance_variable_get("@#{scope}".to_sym)
        # we need a scope id
        if !params.has_key?("#{scope}_id")
          halt 400, "Missing scope identifier: #{scope}"
        end

        scope_id = params["#{scope}_id"].to_i

        # validate that there is such a scope
        if !@user.respond_to?(scope.to_plural)
          halt 400, "Invalid scope: #{scope}"
        end

        # resolve the scope
        unless resolved_scope = @user.send(scope.to_plural).get(scope_id)
          halt 400, "No such #{scope}##{scope_id} for user##{@user.id}"
        end

        # define it so we don't have to resolve it in any subsequent entries
        instance_variable_set("@#{scope}".to_sym, resolved_scope)


      end

      unless resolved_collection = instance_variable_get(coll_key)
        if !resolved_scope.respond_to?(collection.to_sym)
          halt 400, "Invalid collection '#{collection}' in scope #{scope}"
        end

        resolved_collection = resolved_scope.send(collection)
        instance_variable_set(coll_key, resolved_collection)

      end

      # attach it to the entry so we have access to it in our processing below
      entry[:resolved_scope] = resolved_scope
      entry[:collection]     = resolved_collection
      entry[:collection_id]  = collection
    end

    # Validate 'data' key integrity
    if required_keys.include?('data')
      unless entry['data'].is_a?(Hash)
        halt 400, "Malformed journal structure: expected :data to be a Hash, got #{entry['data'].class.name}"
      end
    end

  end
end

post '/users/:user_id/journal',
  auth:     [ :user ],
  provides: [ :json ],
  requires: [ :user ] do

  # puts "Journal parameters: #{params}"

  api_optional!({
    create: lambda  { |entries| validate_journal_entries(entries, [ 'id', 'scope', 'data' ]) },
    update: lambda  { |entries| validate_journal_entries(entries, [ 'id', 'scope', 'data' ]) },
    destroy: lambda { |entries| validate_journal_entries(entries, [ 'id', 'scope' ]) },
  })

  entries = { create: [], update: [], destroy: [] }
  errors  = []
  shadows = {}

  # some nice stats
  processed = { total: 0, create: [], update: [], destroy: [] }

  mark_as_processed = lambda { |optype, entry|
    processed[:total] += 1
    processed[optype] << {
      id: entry['id'],
      scope: entry['scope']
    }
  }

  mark_as_dropped = lambda { |optype, entry, *err|
    errors << [ optype, entry['scope'], entry['id'], err ].flatten
  }

  api_consume! :create do |v|  entries[:create]  = v end
  api_consume! :update do |v|  entries[:update]  = v end
  api_consume! :destroy do |v| entries[:destroy] = v end

  api_clear!

  entries[:destroy].each do |entry|
    collection  = entry[:collection]
    model       = collection.get(entry['id'])

    if !model || !model.destroy
      mark_as_dropped.call :destroy, entry
    else
      mark_as_processed.call :destroy, entry
    end

    # delete any create or update entries that are operating on this resource
    [ entries[:create], entries[:update] ].each { |sibling_entries|
      sibling_entries.delete_if { |sibling_entry|
        entry['scope'] == sibling_entry['scope'] && entry['id'] == sibling_entry['id']
      }
    }
  end

  entries[:create].each do |entry|
    factory, resource = "#{entry['scope'].gsub(':', '_')}_create", nil

    unless self.respond_to?(factory)
      halt 400, "Unrecognized operation"
    end

    shadows[ entry['scope'] ] ||= {}

    if shadows[ entry['scope'] ][ entry['id'] ]
      halt 400, "Duplicate shadow resource #{entry['scope']}##{entry['id']}"
    end

    rc, err = catch :halt do
      api_clear!
      resource = self.send(factory, entry['data'] || {})
      nil
    end

    if (rc && err) || !resource.saved?
      mark_as_dropped.call :create, entry, (err || resource.errors)
      next
    end

    # map the shadow id to the real resource id
    # puts "mapping shadow #{entry['scope']}:#{entry['id']} to #{resource.id}"
    shadows[ entry['scope'] ][ entry['id'] ] = resource.id

    mark_as_processed.call :create, entry
  end

  entries[:update].each do |entry|
    factory, resource = "#{entry['scope'].gsub(':', '_')}_update", nil

    # check if it's a shadow resource
    resource_id = (shadows[entry['scope']] || {})[entry['id']] || entry['id']

    unless self.respond_to?(factory)
      halt 400, "Unrecognized operation"
    end

    unless resource = entry[:collection].get(resource_id)
      halt 400, "No such resource##{entry['id']} in collection #{entry[:collection_id]}"
    end

    rc, err = catch :halt do
      api_clear!
      resource = self.send(factory, resource, entry['data'] || {})
      nil
    end

    if (rc && err) || resource.dirty?
      mark_as_dropped.call :update, entry, (err || resource.errors)
      next
    end

    mark_as_processed.call :update, entry
  end

  @journal = {
    shadows: shadows,
    errors:  errors,
    processed: processed
  }

  respond_with @journal do |f|
    f.json do
      rabl :"users/journal"
    end
  end
end
