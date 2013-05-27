class Journal
  include DataMapper::Resource

  attr_accessor :processed, :dropped, :entries, :shadowmap, :scopemap, :operator

  property :id, Serial
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

  def initialize(data)
    me = super(JSON.parse(data.to_json))

    @scopemap ||= {}
    @entries  ||= {}

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

    @scopes['user'] = self.user
    @collections['users'] = User

    validate_structure!

    # resolve scopes and collections, and validate operation entries
    @entries.each_pair do |scope, collections|
      resolved_scope = resolve_scope!(scope, @user)

      collections.each_pair do |collection, operations|
        resolve_collection!(collection, resolved_scope)

        validate!(:create, operations)
        validate!(:update, operations)
        validate!(:delete, operations)
      end
    end

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

  private

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

  def has_scope_identifier?(scope)
    !!scope_identifier(scope)
  end

  # Current structure:
  #
  # {
  #   "scopemap": {
  #     "[SCOPE]_id": 1
  #   },
  #   "entries": {
  #     "[SCOPE]" {
  #       "[COLLECTION]": {
  #         "[OPERATION]": []
  #       }
  #     }
  #   }
  # }
  def validate_structure!
    unless @scopemap.is_a?(Hash)
      reject! :structure, 'Scope map must be of type Hash, got ' + @scopemap.class.name
    end

    unless @entries.is_a?(Hash)
      reject! :structure, 'Scope listing must be of type Hash, got ' + @entries.class.name
    end

    @entries.each_pair do |scope, collections|
      unless has_scope_identifier? scope
        reject! :structure, "Missing scope identifier in scopemap for scope '#{scope.to_s}'"
      end

      unless collections.is_a?(Hash)
        reject! :structure, 'Collections must be of type Hash, got ' + collections.class.name
      end

      collections.each_pair do |collection, operations|
        unless operations.is_a?(Hash)
          reject! :structure, 'Collection operations must be of type Hash, got ' + operations.class.name
        end

        operations.each_pair do |op, entries|
          unless [ :create, :update, :delete ].include?(op.to_sym)
            reject! :structure, "Unrecognized operation #{op}, supported operations are: [create, update, delete]"
          end

          unless entries.is_a?(Array)
            reject! :structure, "Collection operation entries must be of type Array, got #{entries.class.name}"
          end
        end # scope collection operations

      end # scope collections

    end # scopes
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
    entries = (entries || {})[op.to_s]
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

  def resolve_scope!(key, parent_scope = self.user)
    unless resolved_scope = @scopes[key]
      # validate that there actually is such a scope
      unless parent_scope.respond_to?(key.to_plural)
        reject! :scopes, "Unrecognized scope: #{key}"
      end

      # we need a scope id
      unless @scopemap.has_key?("#{key}_id")
        reject! :scopes, "Missing scope identifier: #{key}"
      end

      scope_id = scope_identifier(key).to_i

      # resolve the scope instance
      unless resolved_scope = parent_scope.send(key.to_plural).get(scope_id)
        reject! :scopes, "No such #{key}##{scope_id} for #{parent_scope.class.name}##{parent_scope.id}"
      end

      # define it so we don't have to resolve it in any subsequent entries
      @scopes[key] = resolved_scope

      # inject the operator with the scope so the factories have access to it, if needed
      operator.instance_variable_set("@#{key}", resolved_scope)
    end

    resolved_scope
  end

  def resolve_collection!(key, scope)
    unless resolved_collection = @collections[key]
      if !scope.respond_to?(key.to_sym)
        reject! :collections, "Unrecognized collection '#{key}' in scope #{scope.class.name}"
      end

      resolved_collection = @collections[key] = scope.send(key)

      # inject the operator with the collection so the factories have access to it, if needed
      operator.instance_variable_set("@#{key}", resolved_collection)
    end

    resolved_collection
  end

  def preprocess
    @ctx.stage = :preprocessing

    @entries.each_pair do |sid, collections|
      @ctx.scope = @scopes[sid]

      collections.each_pair do |cid, operations|
        @ctx.collection = @collections[cid]
        @ctx.operations = operations

        operations.each_pair do |op, entries|
          @ctx.entries = entries

          method_id = "preprocess_#{op}".to_sym
          entries.each_with_index do |entry, idx|
            send(method_id, entry, idx)
          end
        end # collection operations
      end # scope collections
    end # scopes
  end

  def process
    @entries.each_pair do |sid, collections|
      @ctx.scope = @scopes[sid]

      collections.each_pair do |cid, operations|
        @ctx.collection = @collections[cid]
        @ctx.operations = operations

        operations.each_pair do |op, entries|
          @ctx.entries = entries

          method_id = "process_#{op}".to_sym
          entries.each do |entry|
            send(method_id, entry)
          end
        end # collection operations
      end # scope collections
    end # scopes
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