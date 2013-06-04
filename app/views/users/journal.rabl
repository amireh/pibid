object @journal

node(:id) { |r| r.id }
node(:processed) do |j| j.processed end
node(:shadowmap) do |j| j.shadowmap end
node(:dropped) do |j| j.dropped end