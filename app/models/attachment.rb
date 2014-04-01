class Attachment
  include DataMapper::Resource

  attr_accessor :contents

  class << self
    attr_accessor :upload_path
  end

  property :id, Serial
  property :filename, String, length: 255
  property :filepath, String, length: 255
  property :filesize, Integer
  property :created_at,  DateTime, default: lambda { |*_| DateTime.now.utc }

  belongs_to :transaction, required: true

  before :save do
    unless contents.present?
      errors.add :contents, 'missing file contents'
      throw :halt
    end

    puts "user:"
    puts "#{self.transaction.account.user.id}"
    puts self.class.upload_path
    puts "%s_%s" % [ Time.now.to_i, self.filename ]

    begin
    self.filepath = File.join(
      self.class.upload_path,
      self.transaction.account.user.id.to_s,
      "%s_%s" % [ Time.now.to_i.to_s, self.filename ])

    puts "Saving attachment to #{self.filepath}"
  rescue Exception => e
    puts e.message
    puts e.backtrace
    return
  end

    self.filesize = contents.length

    FileUtils.mkdir_p(File.dirname(self.filepath))
    File.write(self.filepath, contents)
  end

  before :destroy do
    begin
      FileUtils.rm(self.filepath)
    rescue
      nil
    end
  end

  def url
    '%s/attachments/%s' % [ self.transaction.url(true), id ]
  end
end