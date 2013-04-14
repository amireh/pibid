module Pibi
  module Helpers

    def password_salt()
      rand(36**16).to_s(32)[0..6]
    end

    def tiny_salt(r = 3)
      (Base64.urlsafe_encode64 Random.rand(1234 * (10**r)).to_s(8)).to_s.sanitize
    end

    def sane_salt(pepper)
      Base64.urlsafe_encode64( pepper + Time.now.to_s)
    end

    def salt(pepper = "")
      pepper = Random.rand(12345 * 1000).to_s if pepper.empty?
      pepper = pepper + Random.rand(1234).to_s
      sane_salt(pepper)
    end

    # def pretty_time(datetime)
    #   datetime.strftime("%D")
    # end

    # def pluralize(number, word)
    #   number == 1 ? "#{number} #{word}" : "#{number} #{word}s"
    # end

    # def vowelize(word)
    #   word.to_s.vowelize
    # end

    # def ordinalized_date(date)
    #   month = date.strftime('%B')
    #   day   = DataMapper::Inflector.ordinalize(date.day)
    #   year  = date.year

    #   "the #{day} of #{month}., #{year}"
    # end
  end
end

helpers do
  include Pibi::Helpers

  def provider_name(p)
    provider = ''
    if p.is_a?(User)
      provider = p.provider
    else
      provider = p
    end

    case provider.to_s
    when 'pibi';          'Pibi'
    when 'facebook';      'Facebook'
    when 'developer';     'developer'
    when 'twitter';       'Twitter'
    when 'github';        'GitHub'
    when 'google_oauth2'; 'Google'
    end
  end

  def pretty_time(datetime)
    datetime.strftime("%D")
  end

  def h(*args)
    ERB::Util.h(*args)
  end
end