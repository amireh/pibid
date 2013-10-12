class Journal
  include DataMapper::Resource

  attr_accessor :processed,
    :dropped,
    :entries,
    :shadowmap,
    :scopemap,
    :operator

  property :id, Serial
  property :data, Text, default: '{}', length: 2**24-1 # 16 MBytes (MySQL MEDIUMTEXT)
  property :created_at, DateTime, default: lambda { |*r| DateTime.now.utc }
  belongs_to :user

  Operations      = [ :create, :update, :delete ]
  CallbackStages  = [ :on_process ]

  RequiredKeys    = {
    create: [ 'id', 'data' ],
    update: [ 'id', 'data' ],
    delete: [ 'id' ]
  }

  EC_RESOURCE_GONE = 1
  EC_RESOURCE_OVERWRITTEN = 2
  EC_RESOURCE_NOT_FOUND = 3

  class Context
    attr_accessor :stage, :scope, :collection, :operations, :entries

    def preprocessing?
      @stage == :preprocessing
    end

    def processing?
      @stage == :processing
    end
  end

  module GlobalScopeAccessors
    def users
      User
    end
  end

  def initialize(data)
    me = super(JSON.parse(data.to_json))

    @entries ||= {}
    @ctx = Context.new

    # resolved scopes and collections
    @scopes         = {}
    @collections    = {}

    # resolved shadow keys
    @shadowmap  = {}

    # processed & dropped entries
    @processed  = {}
    @dropped    = {}

    @callbacks = {}
    CallbackStages.each { |stage| @callbacks[stage] = [] }

    @factories = {}

    me
  end

  def commit(in_operator, options = {})
    unless self.operator = in_operator
      throw "bad journal context, no operator has been assigned!"
    end

    @options = {
      graceful: true
    }.merge(options)

    validate_structure!
    resolve_dependencies

    # resolve scopes and collections, and validate operation entries
    traverse(@entries, {
      on_collection: lambda do |collection, operations|
        validate!(:create, operations)
        validate!(:update, operations)
        validate!(:delete, operations)
      end
    })

    preprocess
    process
  end

  def erratic?
    errors.empty?
  end

  def graceful?
    @options[:graceful]
  end

  def add_callback(stage, &method)
    unless CallbackStages.include?(stage)
      throw "unsupported journal callback stage #{stage}, supported callback stages are #{CallbackStages.join(', ')}"
    end

    @callbacks[stage] << method
  end

  def traverse(entries = @entries, handlers = {})
    entries = entries.with_indifferent_access
    entries.each_pair do |key, entry|
      if entry.is_a?(Array)
        enter_scope(key, entry, nil, handlers)
      elsif entry.is_a?(Hash)
        enter_collection(self, key, entry, &handlers[:on_collection])
      end
    end
  end

  def enter_collection(scope, name, operations, &callback)
    collection = resolve_collection!(name, scope)
    callback.call(collection, operations) if callback
  end

  def enter_scope(name, instances, master_scope = nil, handlers = {})
    instances.each do |instance|
      if !instance.has_key?(:id)
        reject! :scopes, "Missing scope instance id for scope #{name} => #{instance}"
      end

      scope = resolve_scope!(name, instance[:id], master_scope)

      if scope.is_a?(User)
        scope.extend(GlobalScopeAccessors)
      end

      handlers[:on_scope].call(scope, instance) if handlers[:on_scope]

      # Now we get to parse the scope's subscopes / collections
      instance.each_pair do |entry_name, entry|
        if entry.is_a?(Array)
          # A sub-scope
          enter_scope(entry_name, entry, scope, handlers)
        elsif entry.is_a?(Hash)
          # A scope collection
          enter_collection(scope, entry_name, entry, &handlers[:on_collection])
        end
      end
    end
  end

  private

  PriorityList = [
    :users,
    :categories,
    :payment_methods,
    :accounts,
    :transactions,
    :recurrings,
    :id,
    :delete,
    :update,
    :create
  ]

  def __sort(hash, key)
    hash[key] = Hash[hash[key].sort_by { |k,v|
      PriorityList.index(k.to_sym) || -1
    }]
  end

  def resolve_dependencies()
    @entries = Hash[@entries.sort_by { |k,v|
      scope_idx = PriorityList.index(k.to_sym)

      if scope_idx.nil?
        reject! :structure, "Unknown scope '#{k}'."
      end

      scope_idx
    }]

    @entries.each_pair { |scope, collections|
      if collections.is_a?(Hash)
        __sort(@entries, scope)
      elsif collections.is_a?(Array)
        collections.each_with_index do |entry, i|
          if entry.is_a?(Hash)
            __sort(collections, i)
          end
        end
      end
    }
  end

  def factory_for(collection, operation)
    # @factories[factory_id(collection, operation)]
    begin
      operator.method(factory_id(collection, operation))
    rescue NameError => e
      nil
    end
  end

  def factory_id(collection, operation)
    [ collection, operation ].join('_')
  end

  def reject!(property, cause)
    errors.add property, cause
    raise ArgumentError, cause
  end

  def scope_identifier(scope)
    if scope == 'user' then
      return self.user.id
    end

    @scopemap["#{scope.to_s}_id"]
  end

  # Current structure:
  #
  # {
  #   "entries": {
  #     "[SCOPE]" [{
  #       "[SUBSCOPE]": [{
  #         ...
  #       }],
  #
  #       "[COLLECTION]": {
  #         "[OPERATION]": []
  #       }
  #     }]
  #   }
  # }
  def validate_structure!
    unless @entries.is_a?(Hash)
      reject! :structure, 'Scope listing must be of type Hash, got ' + @entries.class.name
    end

    @entries = @entries.with_indifferent_access

    @entries.each_pair do |k, v|
      if v.is_a?(Hash)
        validate_scope_collection!(k, v)
      elsif v.is_a?(Array)
        validate_scope!(k, v)
      end
    end # scopes
  end

  # Expected structure:
  #
  # {
  #   "[SCOPE]" [{
  #     "[SUBSCOPE]": [{
  #       ...
  #     }],
  #     "[COLLECTION]": {
  #       "[OPERATION]": []
  #     }
  #   }]
  # }
  def validate_scope!(name, entries)
    unless entries.is_a?(Array)
      reject! :structure, 'Scope entries must be of type Array, got ' + entries.class.name
    end

    entries.each do |entry|
      unless entry.has_key?(:id)
        reject! :structure, "Missing scope identifier for scope '#{name.to_s}'"
      end

      entry.each_pair do |k, v|

        if v.is_a?(Array)
          # A sub-scope
          validate_scope!(k, v)
        elsif v.is_a?(Hash)
          # A scope collection
          validate_scope_collection!(k, v)
        end
      end # scope collections
    end
  end

  # Expected structure:
  #
  # {
  #   "[COLLECTION]": {
  #     "[create]": [],
  #     "[update]": [],
  #     "[delete]": []
  #   }
  # }
  def validate_scope_collection!(collection, operations)
    unless operations.is_a?(Hash)
      reject! :structure, 'Collection operations must be of type Hash, got ' + operations.class.name
    end

    operations.each_pair do |op, entries|
      unless %w[ create update delete ].include?(op.to_s)
        reject! :structure, "Unrecognized operation #{op}, supported operations are: [create, update, delete]"
      end

      unless entries.is_a?(Array)
        reject! :structure, "Collection operation entries must be of type Array, got #{entries.class.name}"
      end
    end # scope collection operations
  end

  # Validates the specified operation entry listing for structure validity,
  # by going through the entries and validating that the specified required
  # keys are existent and valid within the entry.
  #
  # Each valid entry will have two new keys defined, if applicable:
  #
  # => [:scope] the resolved scope specified in the entry key 'scope' (if any)
  # => [:collection] the resolved scope collection specified in the entry key 'scope' (if any)
  #
  # @error :structure, if entry listing is not an array
  # @error :entries, entry is not a Hash
  # @error :entries, missing a required key
  # @error :entries, 'data' is a required key and entry['data'] is not a Hash
  #
  # @see resolve_scope
  # @see resolve_collection
  def validate!(op, entries)
    entries = (entries || {}).with_indifferent_access
    entries = entries[op]

    return true if !entries

    unless entries.is_a?(Array)
      reject! :structure, "Entry listing must be an array, got #{entries.class.name}"
    end

    required_keys = RequiredKeys[op.to_sym]

    entries.each do |entry|
      unless entry.is_a?(Hash)
        reject! :entries, "Expected entry to be a Hash, got #{entry.class.name}"
      end

      required_keys.each do |key|
        reject! :entries, "Missing required entry data '#{key}'" if !entry.has_key?(key)
      end

      # Validate 'data' key integrity
      if required_keys.include?('data')
        unless entry['data'].is_a?(Hash)
          reject! :entries, "Expected :data to be a Hash, got #{entry['data'].class.name}"
        end
      end
    end

    true
  end

  # Locates a single entity within a container given its class name and its id.
  #
  # @param [String] key
  # The name of the "collection" the scope can be found in in the parent scope.
  #
  # @param [Fixnum] id
  # The id of the single scope that we're resolving.
  #
  # @param [Object] parent_scope
  #
  # If specified, the object is expected to have "key" as a collection that responds
  # to #get. If not specified, "key" will be singularized (if needed) and evaluated
  # and must respond to #get.
  #
  # @example
  #   resolve_scope!("user", 1, nil) # => User.get(1)
  #   resolve_scope!("account", 1, user) # => user.accounts.get(1)
  def resolve_scope!(key, scope_id, parent_scope = nil)
    key = key.to_s
    scope_id = scope_id.to_i

    cache_key = [
      parent_scope.class.to_s.singularize,
      key.pluralize,
      scope_id
    ].join('_')

    unless resolved_scope = @scopes[cache_key]
      container = if parent_scope
        # validate that there actually is such a scope within the parent scope
        unless parent_scope.respond_to?(key.to_plural)
          reject! :scopes, "Unrecognized scope: #{key} in #{parent_scope.class.to_s}"
        end

        parent_scope.send(key.to_plural)
      else
        # Right, this evaluates to User if key is "users"
        #
        # TODO: we can ditch eval for use of a pre-defined mapping of scopes/containers
        __global_scope(key)
      end

      # resolve the scope instance
      unless resolved_scope = container.get(scope_id)
        reject! :scopes, "No such #{key}##{scope_id} for #{parent_scope.class.name}##{parent_scope.id}"
      end

      # define it so we don't have to resolve it in any subsequent entries
      @scopes[cache_key] = resolved_scope

      # inject the operator with the scope so the factories have access to it, if needed
      # operator.instance_variable_set("@#{key}", resolved_scope)
    end

    resolved_scope
  end

  def __global_scope(key)
    eval(key.singularize.camelize)
  end

  # Locates a collection identified by "key" for a given resource.
  #
  # @param [String] key
  # The (singular or plural) name of the attribute that is the collection.
  #
  # @param [DataMapper::Resource] scope
  # The resource that contains the collection, like a User or an Account.
  #
  # @example
  #
  #     resolve_collection!("accounts", User.first)
  #     resolve_collection!("transactions", Account.first)
  #
  def resolve_collection!(key, scope)
    key = key.to_s.pluralize

    cache_key = [
      scope.class.to_s,
      scope.id.to_s,
      key
    ].join('_')


    unless resolved_collection = @collections[cache_key]
      if !scope.respond_to?(key)
        reject! :collections, "Unrecognized collection '#{key}' in scope #{scope}"
      end

      resolved_collection = @collections[cache_key] = scope.send(key)

      @scopes[ resolved_collection ] = scope
      # inject the operator with the collection so the factories have access to it, if needed
      # operator.instance_variable_set("@#{key}", resolved_collection)
    end

    resolved_collection
  end

  def preprocess
    @ctx.stage = :preprocessing

    traverse(@entries, {
      on_scope: lambda do |scope, _|
        @ctx.scope = scope
      end,

      on_collection: lambda do |collection, operations|
        # @ctx.collection = @collections[cid]
        @ctx.collection = collection
        @ctx.operations = operations
        @ctx.scope = @scopes[ collection ]

        operations.each_pair do |op, entries|
          @ctx.entries = entries

          method_id = "preprocess_#{op}".to_sym
          entries.each_with_index do |entry, idx|
            send(method_id, entry, idx)
          end
        end # collection operations
      end
    })
  end

  def process
    traverse(@entries, {
      on_scope: lambda do |scope, _|
        @ctx.scope = scope
      end,

      on_collection: lambda do |collection, operations|
        @ctx.collection = collection
        @ctx.operations = operations
        @ctx.scope = @scopes[ collection ]

        operations.each_pair do |op, entries|
          @ctx.entries = entries

          method_id = "process_#{op}".to_sym
          entries.each do |entry|
            send(method_id, entry)
          end
        end # collection operations
      end
    })
  end

  def mark_processed(op, entry)
    sid, cid = current_scope_id, current_collection_id

    # @processed[:total] += 1

    @processed[sid] ||= {}
    @processed[sid][cid] ||= {}
    @processed[sid][cid][op.to_sym] ||= []

    @processed[sid][cid][op.to_sym] << {
      id: entry['id']
    }

    true
  end

  def mark_dropped(op, entry, *err)
    sid, cid = current_scope_id, current_collection_id

    @dropped[sid] ||= {}
    @dropped[sid][cid] ||= {}
    @dropped[sid][cid][op.to_sym] ||= []
    @dropped[sid][cid][op.to_sym] << {
      id: entry['id'],
      errors: [ err ].flatten
    }

    false
  end

  def preprocess_delete(entry, idx)
    entry['id'] = entry['id'].to_i
  end

  def process_delete(entry)
    model = @ctx.collection.get(entry['id'])

    if status = model && model.destroy
      # delete any create or update entries that are operating on this resource

      [ @ctx.operations['create'], @ctx.operations['update'] ].each_with_index { |sibling_entries, op_idx|
        next if !sibling_entries

        index = sibling_entries.index { |sibling_entry|
          entry['id'] == sibling_entry['id']
        }

        if index
          mark_dropped([:create,:update][op_idx], sibling_entries[index], EC_RESOURCE_GONE)
        end
      }

      mark_processed :delete, entry
    else
      mark_dropped :delete, entry, (model && model.errors)
    end

    status
  end

  def current_scope_id
    @ctx.scope.class.name.underscore.downcase
  end

  def current_collection_id
    @ctx.collection.name.underscore.to_plural.downcase
  end

  def current_collection_fqid()
    [
      current_scope_id,
      current_collection_id
    ].map(&:downcase).join('_')
  end

  def can_create?(collection)
    !!factory_for(collection, :create)
  end

  def can_update?(collection)
    !!factory_for(collection, :update)
  end

  def map_shadow_resource(shadow_id, resource)
    sid, cid = current_scope_id, current_collection_id

    @shadowmap[sid] ||= {}
    @shadowmap[sid][cid] ||= {}
    @shadowmap[sid][cid][shadow_id.to_s] = resource.id.to_i

    @ctx.collection.shadow(shadow_id, resource)

    true
  end

  def preprocess_create(entry, entry_idx)
    cid = current_collection_fqid

    # make sure we know how to create this resource
    unless can_create?(cid)
      reject! :create, "Unrecognized operation #{factory_id(cid, :create)}"
    end

    # has there been a CREATE entry with the same shadow id in this collection?
    @ctx.entries.each_with_index { |sibling, idx|
      if sibling['id'] == entry['id'] && idx != entry_idx
        unless graceful?
          reject! :create, "Duplicate shadow resource #{cid}##{entry['id']}"
        end

        # because this is so much easier and cleaner than trying to remove all duplicates
        # from the array, we'll simply test this flag in #process_create
        sibling['dropped'] = true
      end
    }

    # we process the very last CREATE entry for this resource
    entry['dropped'] = false
  end

  def process_create(entry)
    if entry['dropped']
      return mark_dropped :create, entry, EC_RESOURCE_OVERWRITTEN
    end

    factory, resource = factory_for(current_collection_fqid, :create), nil

    rc, err = catch :halt do
      (@callbacks[:on_process] || []).map(&:call)
      resource = factory.call(@ctx.scope, entry['data'] || {})
      nil
    end

    if (rc && err) || !resource.saved?
      return mark_dropped :create, entry, (err || resource.errors)
    end

    # map the shadow id to the real resource id
    # puts "mapping shadow #{entry['scope']}:#{entry['id']} to #{resource.id}"
    map_shadow_resource(entry['id'], resource)

    mark_processed :create, entry
  end

  def preprocess_update(entry,idx)
    cid = current_collection_fqid

    # make sure we know how to create this resource
    unless can_update?(cid)
      reject! :update, "Unrecognized operation #{factory_id(cid, :update)}"
    end

    if @ctx.collection == User then
      entry['id'] = self.user.id
    end

  end

  def process_update(entry)
    factory, resource = factory_for(current_collection_fqid, :update), nil

    unless resource = @ctx.collection.get(entry['id'])
      unless graceful?
        halt 400, "No such resource##{entry['id']} in collection #{current_collection_id}"
      end

      return mark_dropped :update, entry, EC_RESOURCE_NOT_FOUND
    end

    rc, err = catch :halt do
      (@callbacks[:on_process] || []).map(&:call)
      resource = factory.call(resource, entry['data'] || {})
      nil
    end

    if (rc && err) || resource.dirty?
      return mark_dropped :update, entry, (err || resource.errors)
    end

    mark_processed :update, entry
  end
end