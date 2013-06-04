before do
  content_type :json unless request.request_method == 'OPTIONS'
end

options '*' do
  response['Access-Control-Max-Age'] = '1728000'

  halt 200
end

get '/pulse' do
  blank_halt!
end

get '/preferences', :provides => [ :json ] do
  respond_to do |f|
    f.json do
      Pibi::Preferences.defaults['app'].to_json
    end
  end
end

get '/currencies', auth: [ :user ], provides: [ :json ] do
  # halt 400, ''

  respond_to do |f|
    f.json do
      rabl :"currencies/index"
    end
  end
end

post '/submissions/bugs', provides: [ :json ] do
  user = current_user || User.new({ email: "guest@pibiapp.com", name: "Guest" })

  bug_submission = BugSubmission.create({
    details:  (params||{}).to_json,
    user:     current_user
  })

  settings.comlink.broadcast({
    id: "submissions.bug",
    data: {
      id: bug_submission.id,
      user: {
        email: user.email,
        name:  user.name
      },
      filed_at: bug_submission.filed_at,
      details:  params||{}
    }
  })

  unless bug_submission.saved?
    halt 500, bug_submission.errors
  end

  respond_to do |f|
    f.json { '{}' }
  end
end

def blank_halt!(rc = 200)
  halt rc
end

get '/users/:user_id/journals', auth: [ :user ], requires: [ :user ] do
  content_type "text/event-stream"

  stream :keep_open do |out|
    stream = Sinatra::SSE::Stream.new(out)

    settings.connections[current_user.id] ||= []
    settings.connections[current_user.id] << stream

    out.callback {
      settings.connections[current_user.id].delete(stream)
    }

  end
end

EM.next_tick do
  EM.add_periodic_timer(5) do
    settings.connections.each_pair do |user_id, user_connections|
      puts "pinging #{user_connections.length} client devices"

      user_connections.each do |stream|

        stream.push event: "pulse", data: 'boo'
      end
    end
  end
end