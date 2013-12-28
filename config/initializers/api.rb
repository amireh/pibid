configure do
  register Sinatra::API
  Sinatra::API.configure({
    with_errors: false
  })
end