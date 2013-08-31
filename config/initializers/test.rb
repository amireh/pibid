configure do
  set :comlink, Object.new
  comlink = settings.comlink

  def comlink.broadcast(*args)
    true
  end

  def comlink.run(*args)
    true
  end

  def comlink.stop(*args)
    true
  end
end