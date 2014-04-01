object @attachment => ''

attributes :filename, :filesize

node(:id) { |r| r.id }
node(:filename) { |r| r.filename }
node(:filesize) { |r| r.filesize }
node(:created_at) { |r| r.created_at }

node(:media) do |attachment|
  {
    url: attachment.url
  }
end