object @user

attributes :id, :name, :email

child :account do
  attributes :currency, :balance
end