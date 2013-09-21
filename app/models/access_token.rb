class AccessToken
  include DataMapper::Resource

  def self.salt
    ''
  end

  property :digest, String, key: true, default: lambda { |access_token, *_|
    Digest::SHA1.hexdigest([
      access_token.udid,
      AccessToken.salt,
      access_token.user.id
    ].join('_'))
  }

  property :udid, String, allow_nil: false

  belongs_to :user

  validates_uniqueness_of :udid, :scope => [ :user_id ],
    message: 'That UDID already has an access token.'

  before :save do
  end
end