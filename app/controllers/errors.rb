def on_api_error(msg = response.body)
  if request.request_method == 'OPTIONS'
    content_type :text
    halt response.status
  end

  # content_type  :json
  status        response.status
  # response['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept'
  # response['Access-Control-Allow-Headers'] = 'origin, x-requested-with, content-type, accept'

  errmap = {}

  msg = case
  when msg.is_a?(String)
    [ msg ]
  when msg.is_a?(Array)
    msg
  when msg.is_a?(Hash)
    errmap = msg
    msg.collect { |k,v| v }
  when msg.is_a?(DataMapper::Validations::ValidationErrors)
    errmap = msg.to_hash
    msg.to_hash.collect { |k,v| v }.flatten
  else
    [ "unexpected response: #{msg.class} -> #{msg}" ]
  end

  {
    :status        => 'error',
    :messages      => msg,
    :field_errors  => errmap
  }
end

# error do
#   on_api_error.to_json
# end

error Sinatra::NotFound do
  return if @internal_error_handled
  @internal_error_handled = true


  if settings.test?
    on_api_error("No such resource. URI: #{request.path}, Params: #{params.inspect}").to_json
  else
    on_api_error("No such resource.").to_json
  end
end

error 400..404 do
  return if @internal_error_handled
  @internal_error_handled = true

  on_api_error.to_json
end

# [ 401, 403, 404 ].each do |http_rc|
#   error http_rc do
#     return if @internal_error_handled
#     @internal_error_handled = true

#     respond_to do |f|
#       f.json { on_api_error.to_json }
#     end
#   end
# end

error 500..503 do
  return if @internal_error_handled
  @internal_error_handled = true

  # if !settings.intercept_internal_errors
  #   raise request.env['sinatra.error']
  # end

  begin
    courier.report_error(request.env['sinatra.error'])
  rescue Exception => e
    # raise e
  end

  if settings.test?

    on_api_error(request.env['sinatra.error'] || response.body).to_json
  else
    on_api_error("Internal error").to_json
  end
end