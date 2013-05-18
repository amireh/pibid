module Journal
  include DataMapper::Resource

  class << self
    # attr_accessor :factories

    def add_callback(stage, &method)
      @@callbacks ||= {}
      @@callbacks[stage] = method
    end

    def register_factory(entity, operation, method)
      @@factories ||= {}
      id = factory_id(entity, operation)
      puts "[journal]: registering factory #{id}"

      @@factories[id] = method.unbind
    end

    def factory_for(entry_scope, operation)
      @@factories ||= {}
      @@factories[factory_id(entry_scope, operation)]
    end

    def factory_id(entity, operation)
      "#{entity.to_s.gsub(':','_')}_#{operation}"
    end
  end

  attr_accessor :processed, :entries, :shadowmap, :scopemap, :operator

  property :id, Serial
  belongs_to :user

  def initialize(data)
    me = super(data)

    @scopemap ||= {}
    @entries  ||= {}

    # resolved scopes and collections
    @scopes      = {}
    @collections = {}

    # resolved shadow keys
    @shadowmap  = {}

    # processed & dropped entries
    @processed  = { total: 0, create: [], update: [], delete: [] }
    @dropped    = { total: 0, create: [], update: [], delete: [] }

    @_creates, @_updates = {}, {}

    @@callbacks ||= {}

    me
  end

  def commit(options = {})
    @options = {
      graceful: true
    }.merge(options)

    validate_structure!

    validate!(:create, [ 'id', 'scope', 'data' ]) if @entries['create']
    validate!(:update, [ 'id', 'scope', 'data' ]) if @entries['update']
    validate!(:delete, [ 'id', 'scope' ]) if @entries['delete']

    preprocess
    process
  end

  def erratic?
    errors.empty?
  end

  def graceful?
    @options[:graceful]
  end

  private

  def reject!(property, cause)
    errors.add property, cause
    # throw :halt, cause
    raise ArgumentError, cause
  end

  def validate_structure!
    unless @scopemap.is_a?(Hash)
      reject! :structure, 'Journal scope map must be of type Hash, got ' + @scopemap.class.name
    end

    unless @entries.is_a?(Hash)
      reject! :structure, 'Journal entry listing must be of type Hash, got ' + @entries.class.name
    end

    @entries.each_pair do |op, entries|
      unless [ :create, :update, :delete ].include?(op.to_sym)
        reject! :structure, "Unrecognized operation #{op}, supported operations are: [create, update, delete]"
      end

      unless entries.is_a?(Array)
        reject! :structure, "#{op} entries must be of type Array, got #{entries.class.name}"
      end
    end
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
  def validate!(op, required_keys)
    entries = @entries[op.to_s]

    unless entries.is_a?(Array)
      reject! :structure, "Entry listing must be an array, got #{entries.class.name}"
    end

    entries.each do |entry|
      unless entry.is_a?(Hash)
        reject! :entries, "Expected entry to be a Hash, got #{entry.class.name}"
      end

      required_keys.each do |key|
        reject! :entries, "Missing required entry data '#{key}'" if !entry.has_key?(key)
      end

      # resolve the scope and collection
      if required_keys.include?('scope')
        fragments = entry['scope'].split(':')

        resolved_scope      = resolve_scope!(fragments.first, @user)
        resolved_collection = resolve_collection!(fragments.last, resolved_scope)

        # attach it to the entry so we have access to it in our processing below
        entry.merge!({
          resolved_scope: resolved_scope,
          collection:     resolved_collection
        })
      end

      # Validate 'data' key integrity
      if required_keys.include?('data')
        unless entry['data'].is_a?(Hash)
          reject! :entries, "Expected :data to be a Hash, got #{entry['data'].class.name}"
        end
      end
    end
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

      scope_id = @scopemap["#{key}_id"].to_i

      # resolve the scope instance
      unless resolved_scope = parent_scope.send(key.to_plural).get(scope_id)
        reject! :scopes, "No such #{key}##{scope_id} for #{parent_scope.class.name}##{parent_scope.id}"
      end

      # define it so we don't have to resolve it in any subsequent entries
      @scopes[key] = resolved_scope
    end

    resolved_scope
  end

  def resolve_collection!(key, scope)
    unless resolved_collection = @collections[key]
      if !scope.respond_to?(key.to_sym)
        reject! :collections, "Unrecognized collection '#{key}' in scope #{scope.class.name}"
      end

      resolved_collection = @collections[key] = scope.send(key)
    end

    resolved_collection
  end

  def preprocess
    @entries.each_pair do |op, entries|
      method_id = "preprocess_#{op}".to_sym

      entries.each do |entry|
        send(method_id, entry)
      end
    end
  end

  def process
    @entries.each_pair do |op, entries|
      method_id = "process_#{op}".to_sym

      entries.each do |entry|
        send(method_id, entry)
      end
    end
  end

  def mark_processed(op, entry)
    @processed[:total] += 1
    @processed[op.to_sym] << {
      id:     entry['id'],
      scope:  entry['scope']
    }

    true
  end

  def mark_dropped(op, entry, *err)
    @dropped[op.to_sym] << [ entry['scope'], entry['id'], err ].flatten

    false
  end

  def preprocess_delete(entry)
  end

  def process_delete(entry)
    collection  = entry[:collection]
    model       = collection.get(entry['id'])

    if status = model && model.destroy
      # delete any create or update entries that are operating on this resource
      [ @entries['create'], @entries['update'] ].each { |sibling_entries|
        next if !sibling_entries

        sibling_entries.delete_if { |sibling_entry|
          entry['scope']  == sibling_entry['scope'] &&
          entry['id']     == sibling_entry['id']
        }
      }

      mark_processed :delete, entry
    else
      mark_dropped :delete, entry, (model && model.errors)
    end

    status
  end

  def can_create?(scope)
    !!self.class.factory_for(scope, :create)
  end

  def can_update?(scope, collection)
    !!self.class.factory_for(scope, :update)
  end

  def preprocess_create(entry)
    scope = entry['scope']

    # make sure we know how to create this resource
    unless can_create?(scope)
      reject! :create, "Unrecognized operation #{self.class.factory_id(scope, :create)}"
    end

    @_creates[ scope ] ||= []

    # has there been a CREATE entry with the same shadow id in this scope?
    if existing_entry = @_creates[scope].select { |tracked_entry| tracked_entry['id'] == entry['id'] }
      unless graceful?
        reject! :create, "Duplicate shadow resource #{scope}##{entry['id']}"
      end

      # just override it
      existing_entry = entry
    else
      @_creates[scope] << entry
    end
  end

  def process_create(entry)
    factory, resource = self.class.factory_for(entry['scope'], :create), nil

    # unless self.respond_to?(factory)
    #   halt 400, "Unrecognized operation"
    # end

    @shadowmap[ entry['scope'] ] ||= {}

    rc, err = catch :halt do
      (@@callbacks[:on_process] || []).map(&:call)
      resource = factory.bind(operator).call(entry['data'] || {})
      nil
    end

    if (rc && err) || !resource.saved?
      return mark_dropped :create, entry, (err || resource.errors)
    end

    # map the shadow id to the real resource id
    # puts "mapping shadow #{entry['scope']}:#{entry['id']} to #{resource.id}"
    @shadowmap[ entry['scope'] ][ entry['id'] ] = resource.id

    mark_processed :create, entry
  end

  def process_update(entry)
    # factory, resource = "#{entry['scope'].gsub(':', '_')}_update", nil

    # # check if it's a shadow resource
    # resource_id = (@shadowmap[entry['scope']] || {})[entry['id']] || entry['id']

    # unless self.respond_to?(factory)
    #   halt 400, "Unrecognized operation"
    # end

    # unless resource = entry[:collection].get(resource_id)
    #   halt 400, "No such resource##{entry['id']} in collection #{entry[:collection_id]}"
    # end

    # rc, err = catch :halt do
    #   api_clear!
    #   resource = self.send(factory, resource, entry['data'] || {})
    #   nil
    # end

    # if (rc && err) || resource.dirty?
    #   mark_dropped.call :update, entry, (err || resource.errors)
    #   next
    # end

    # mark_processed.call :update, entry
  end
end