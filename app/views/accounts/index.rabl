node(:accounts) do |accounts|
  @accounts.map { |c| partial "accounts/show", object: c }
end