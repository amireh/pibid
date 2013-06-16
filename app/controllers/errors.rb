def on_api_error(msg = response.body)
  if request.request_method == 'OPTIONS'
    content_type :text
    halt response.status
  end

  status response.status

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

error 500..503 do
  return if @internal_error_handled
  @internal_error_handled = true

  begin
    bug_submission = BugSubmission.create({
      details: { sinatra_error: request.env['sinatra.error'] }.to_json
    })

    settings.comlink.broadcast(:reports, {
      id: "submissions.internal_error",
      data: {
        id: bug_submission.id,
        filed_at: bug_submission.filed_at,
        details:  { sinatra_error: request.env['sinatra.error'] }
      }
    })
  rescue Exception => e
    # raise e
  end

  errbody = request.env['sinatra.error'] || response.body || 'Internal error'

  if settings.test?
    on_api_error(errbody).to_json
  else
    on_api_error(errbody).to_json
  end
end