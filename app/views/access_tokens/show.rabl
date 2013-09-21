object @access_token => ""

node(:digest) do |access_token|
  access_token.digest
end
