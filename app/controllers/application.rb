before do
  content_type :json unless request.request_method == 'OPTIONS'
end

get '/pulse' do
  blank_halt!
end

get '/currencies', auth: [ :user ], provides: [ :json ] do
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

  settings.comlink.broadcast(:reports, {
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