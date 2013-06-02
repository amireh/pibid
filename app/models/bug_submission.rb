class BugSubmission
  include DataMapper::Resource

  property    :id,       Serial
  property    :details,  Text, default: '{}', length: 2**24-1 # 16 MBytes (MySQL MEDIUMTEXT)
  property    :filed_at, DateTime, default: lambda { |*_| DateTime.now }

  belongs_to  :user, required: false
end