require 'app/models/user'
require 'app/models/account'

class Journal
  include DataMapper::Resource

  attr_accessor :processed,
    :dropped,
    :records,
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
    attr_accessor :stage, :scope, :collection, :operations, :entries, :dropped

    def initialize
      @dropped = []
      super
    end

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

    @records ||= {}
    @ctx = Context.new

    # resolved scopes and collections
    @scopes         = {}
    @collections    = {}

    # resolved shadow keys
    @shadowmap  = {}

    # processed & dropped records
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

    # resolve scopes and collections, and validate operation records
    traverse({
      on_collection: lambda do |collection, scope, operations|
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

  Scopes = {
    user: User,
    account: Account
  }

  def requires_global_accessors?(scope)
    scope.is_a?(User)
  end

  def traverse(handlers = {})
    @records.each do |record|
      record = record.with_indifferent_access

      unless scope = Scopes[record[:scope].to_sym]
        reject! :scopes, "Unknown scope #{record[:scope]}"
      end

      unless scope = scope.get(record[:scope_id])
        reject! :scopes, "No such resource #{record[:scope]}##{record[:scope_id]}"
      end

      scope.extend(GlobalScopeAccessors) if requires_global_accessors?(scope)

      handlers[:on_scope].call(scope) if handlers[:on_scope]

      unless scope.respond_to?(record[:collection])
        reject! :scopes, "No such collection #{record[:collection]} in scope #{record[:scope]}"
      end

      collection = scope.send record[:collection]
      operations = record[:operations] || {}

      handlers[:on_collection].call(collection, scope, operations) if handlers[:on_collection]

      operations.each_pair do |opcode, records|
        records.each do |record|
          handlers[:"on_#{opcode}"].call(record, collection, scope) if handlers[:"on_#{opcode}"]
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
    :recurrings
  ]

  def __sort(hash, key)
    hash[key] = Hash[hash[key].sort_by { |k,v|
      PriorityList.index(k.to_sym) || -1
    }]
  end

  def resolve_dependencies()
    @records.sort! { |a, b|
      a = a.with_indifferent_access
      b = b.with_indifferent_access

      PriorityList.index(a[:collection].to_sym) <=> PriorityList.index(b[:collection].to_sym)

      # if scope_idx.nil?
      #   reject! :structure, "Unknown scope '#{k}'."
      # end

      # scope_idx
    }

    # @records.each_pair { |scope, collections|
    #   if collections.is_a?(Hash)
    #     __sort(@records, scope)
    #   elsif collections.is_a?(Array)
    #     collections.each_with_index do |record, i|
    #       if record.is_a?(Hash)
    #         __sort(collections, i)
    #       end
    #     end
    #   end
    # }
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
  #   "records": [{
  #     "scope": "string",
  #     "scope_id": number,
  #     "collection": "string",
  #     "operations": {
  #       "create": [],
  #       "update": [],
  #       "delete": []
  #     }
  #   }]
  # }
  def validate_structure!
    unless @records.is_a?(Array)
      reject! :structure, 'Record listing must be of type Array, got ' + @records.class.name
    end

    @records.each do |record|
      record = record.with_indifferent_access

      %w[ scope scope_id collection ].each do |required_key|
        unless record.has_key?(required_key)
          reject! :structure, "Missing required record key '#{required_key.to_s}'"
        end
      end

      operations = record[:operations] ||= {}

      unless operations.is_a?(Hash)
        reject! :structure, 'Operations must be of type Hash, got ' + operations.class.name
      end

      operations.each_pair do |op, entries|
        unless %w[ create update delete ].include?(op.to_s)
          reject! :structure,
            "Unrecognized operation #{op}, supported operations are: [create, update, delete]"
        end

        unless entries.is_a?(Array)
          reject! :structure,
            "Operation entries must be of type Array, got #{records.class.name}"
        end
      end # collection operations

    end # records
  end

  # Validates the specified operation record listing for structure validity,
  # by going through the records and validating that the specified required
  # keys are existent and valid within the record.
  #
  # Each valid record will have two new keys defined, if applicable:
  #
  # => [:scope] the resolved scope specified in the record key 'scope' (if any)
  # => [:collection] the resolved scope collection specified in the record key 'scope' (if any)
  #
  # @error :structure, if record listing is not an array
  # @error :records, record is not a Hash
  # @error :records, missing a required key
  # @error :records, 'data' is a required key and record['data'] is not a Hash
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

  def preprocess
    @ctx.stage = :preprocessing

    pass do |op, entries|
      handler = method("preprocess_#{op}")

      entries.each_with_index do |entry, idx|
        handler.call(entry, idx)
      end
    end
  end

  def process
    @ctx.stage = :processing

    pass do |op, entries|
      handler = method("process_#{op}")

      entries.each do |entry|
        handler.call(entry)
      end
    end
  end

  def pass
    traverse({
      on_scope: lambda do |scope|
        @ctx.scope = scope
      end,

      on_collection: lambda do |collection, scope, operations|
        @ctx.collection = collection
        @ctx.operations = operations
        @ctx.scope = scope

        operations.each_pair do |op, entries|
          @ctx.entries = entries

          yield(op, entries)
        end # collection operations
      end
    })
  end

  def mark_processed(op, record)
    scope, scope_id, cid = current_scope_id, @ctx.scope.id.to_s, current_collection_id

    # @processed[:total] += 1

    @processed[scope] ||= {}
    @processed[scope][scope_id] ||= {}
    @processed[scope][scope_id][cid] ||= {}
    @processed[scope][scope_id][cid][op.to_sym] ||= []
    @processed[scope][scope_id][cid][op.to_sym] << {
      id: record['id']
    }

    true
  end

  def mark_dropped(op, record, *err)
    scope, scope_id, cid = current_scope_id, @ctx.scope.id.to_s, current_collection_id

    @dropped[scope] ||= {}
    @dropped[scope][scope_id] ||= {}
    @dropped[scope][scope_id][cid] ||= {}
    @dropped[scope][scope_id][cid][op.to_sym] ||= []
    @dropped[scope][scope_id][cid][op.to_sym] << {
      id: record['id'],
      errors: [ err ].flatten
    }

    false
  end

  def map_shadow_resource(shadow_id, resource)
    scope, scope_id, cid = current_scope_id, @ctx.scope.id.to_s, current_collection_id

    @shadowmap[scope] ||= {}
    @shadowmap[scope][scope_id] ||= {}
    @shadowmap[scope][scope_id][cid] ||= {}
    @shadowmap[scope][scope_id][cid][shadow_id.to_s] = resource.id.to_i

    @ctx.collection.shadow(shadow_id, resource)

    true
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

  def can_delete?(*args)
    # we delete stuff manually, no factories required
    true
  end

  def preprocess_create(record, record_idx)
    cid = current_collection_fqid

    # make sure we know how to create this resource
    unless can_create?(cid)
      reject! :create, "Unrecognized operation #{factory_id(cid, :create)}"
    end

    # has there been a CREATE record with the same shadow id in this collection?
    @ctx.entries.each_with_index { |sibling, idx|
      if sibling['id'] == record['id'] && idx != record_idx
        unless graceful?
          reject! :create, "Duplicate shadow resource #{cid}##{record['id']}"
        end

        # because this is so much easier and cleaner than trying to remove all duplicates
        # from the array, we'll simply test this flag in #process_create
        drop sibling
      end
    }

    # we process the very last CREATE record for this resource
    undrop record
  end

  def process_create(record)
    if dropped?(record)
      return mark_dropped :create, record, EC_RESOURCE_OVERWRITTEN
    end

    factory, resource = factory_for(current_collection_fqid, :create), nil

    rc, err = catch :halt do
      (@callbacks[:on_process] || []).map(&:call)
      resource = factory.call(@ctx.scope, record['data'] || {})
      nil
    end

    if (rc && err) || !resource.saved?
      return mark_dropped :create, record, (err || resource.errors)
    end

    # map the shadow id to the real resource id
    # puts "mapping shadow #{record['scope']}:#{record['id']} to #{resource.id}"
    map_shadow_resource(record['id'], resource)

    mark_processed :create, record
  end

  def preprocess_update(record,idx)
    cid = current_collection_fqid

    # make sure we know how to create this resource
    unless can_update?(cid)
      reject! :update, "Unrecognized operation #{factory_id(cid, :update)}"
    end

    if @ctx.collection == User then
      record['id'] = self.user.id
    end
  end

  def process_update(record)
    factory, resource = factory_for(current_collection_fqid, :update), nil

    unless resource = @ctx.collection.get(record['id'])
      unless graceful?
        halt 400, "No such resource##{record['id']} in collection #{current_collection_id}"
      end

      return mark_dropped :update, record, EC_RESOURCE_NOT_FOUND
    end

    rc, err = catch :halt do
      (@callbacks[:on_process] || []).map(&:call)
      resource = factory.call(resource, record['data'] || {})
      nil
    end

    if (rc && err) || resource.dirty?
      return mark_dropped :update, record, (err || resource.errors)
    end

    mark_processed :update, record
  end

  def preprocess_delete(record, idx)
    record['id'] = record['id'].to_i

    # make sure we know how to create this resource
    unless can_delete?
      reject! :delete, "Unrecognized operation #{factory_id(cid, :delete)}"
    end
  end

  def process_delete(record)
    resource = @ctx.collection.get(record['id'])
    factory = factory_for(current_collection_fqid, :delete)
    status = nil

    if resource
      if factory
        rc, err = catch :halt do
          (@callbacks[:on_process] || []).map(&:call)
          status = factory.call(resource)
          nil
        end
      else
        status = resource && resource.destroy
      end
    end

    if status
      # delete any create or update records that are operating on this resource

      [ @ctx.operations['create'], @ctx.operations['update'] ].each_with_index do |sibling_records, op_idx|
        next if !sibling_records

        index = sibling_records.index { |sibling_record|
          record['id'] == sibling_record['id']
        }

        if index
          mark_dropped([:create,:update][op_idx], sibling_records[index], EC_RESOURCE_GONE)
        end
      end

      mark_processed :delete, record
    else
      mark_dropped :delete, record, (resource && resource.errors)
    end

    status
  end

  def drop(record)
    # puts ">> Marked record as dropped (overwritten): #{sibling.to_json}"
    @ctx.dropped << record.hash
  end

  def undrop(record)
    @ctx.dropped.delete(record.hash)
  end

  def dropped?(record)
    @ctx.dropped.include?(record.hash)
  end
end
