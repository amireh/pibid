post '/users/:user_id/reports',
  provides: [ :json ],
  requires: [ :user ],
  auth: [ :user ] do

  api_required!({
    segment: nil
  })

  puts session.id
  puts session.options[:id]

  settings.comlink.broadcast(:jobs, {
    id: "generate_report",
    client: @user.id,
    token: session.id
  })

  respond_to do |f|
    f.json { '{}' }
  end
end