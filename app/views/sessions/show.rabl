object :session => ""

node(:id) { session[:id] }
node(:jar) { session.id }
node(:email) { current_user && current_user.email }
