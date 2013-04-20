class Category
  include DataMapper::Resource

  default_scope(:default).update(:order => [ :name.asc ])

  property :id, Serial
  property :name, String, length: 250
  property :icon, String, length: 35, required: false, default: 'default'

  belongs_to :user, required: true
  has n, :transactions, :through => Resource, :constraint => :skip
  has n, :deposits,     :through => Resource, via: :transaction, :constraint => :skip
  has n, :withdrawals,  :through => Resource, via: :transaction, :constraint => :skip
  has n, :recurrings,   :through => Resource, via: :transaction, :constraint => :skip

  validates_presence_of :name, message: 'You must provide a name for the category!'

  validates_uniqueness_of :name, :scope => [ :user_id ],
    message: 'You already have such a category!'

  validates_length_of :name, min: 3,
    message: 'A category must be at least 3 characters long.'

  before :destroy do
    CategoryTransaction.all({ category_id: self.id }).destroy
  end

  is :transactable

end