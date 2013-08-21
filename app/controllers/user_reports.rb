class UserReportsController
  include Sinatra::Controller

  scope :user
  # endpoint '/users/:user_id'

  configure :show, {
    :requires => [ :user ]
  }

  def show
  end

  def index
  end

  def destroy
  end

  get '/:foobar' do
  end

  register!
end