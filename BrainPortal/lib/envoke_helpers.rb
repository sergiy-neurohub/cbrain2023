
#
# NeuroHub Project
#
# Copyright (C) 2021
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Helper for logging in using Envoke
module EnvokeHelpers

  Revision_info = CbrainFileRevision[__FILE__] #:nodoc:

  require 'uri'
  require 'net/http'
  require 'json'

  require 'pry'
  # require 'cgi'

  ENVOKE_API_BASE = 'https://e1.envoke.com/v1'


  def envoke_api_base
    EnvokeHelpers::ENVOKE_API_BASE
  end

  def envoke_id # Envoke api client id is retrieved from portals meta data
    myself = RemoteResource.current_resource
    myself.meta['envoke_id'] || ENV['ENVOKE_ID'] # for easier testing use envorionment vars, set portal's meta on production
  end

  def envoke_key # Envoke api client id is retrieved from portals meta data
    myself = RemoteResource.current_resource
    myself.meta['envoke_key'] || ENV['ENVOKE_KEY'] || ENV['ENVOKE_AUTH']
  end

  def envoke_auth_configured? # checks for presence of Envoke API credentials
    return false if !envoke_id
    return false if !envoke_key
    true
  end

  def guess_first_name(user) # figure from sign up or guess first name
    signup = user.signup
    # drop the title though no sure 100% may be should be appended into first name
    # fixme a nice name parsing gem like https://github.com/berkmancenter/namae can do better
    full_name = user.full_name.sub(/\A(Dr|Doctor|PhD|PHD|Master|Prof|Herr|Lord|Lady|Mr|Mrs|Ms|Sr|Sir|Madame)\.?\s/, "")
    return signup.first if user.signup && user.signup.first && full_name.include?(user.signup.first)
    return full_name&.split(' ', 2)[0][0, 20].presence # user might changed name
  end

  def guess_second_name(user) # figure from sign up or guess last name from the full name
    signup = user.signup
    return signup.last if signup && user.signup.last && user.full_name.end_with?(signup.last)
    first = guess_first_name(user)
    return "" if first == signup&.full_name
    return user.full_name&.split(first + ' ', 2)[1].presence if user.full_name.start_with?(first + ' ')
    return user.full_name.split[1][0, 20].presence
  end

  # def names  # todo merge two methods?
  #   first
  #
  #   signup = user.signup
  #   return signup.first if user.signup && user.signup.first && user.full_name.start_with?(user.signup.first)
  #   first = gue
  #   return user.full_name&.split(guess' ', 1)[1] # user might changed name
  # end

  # adds a user to envoke contacts list with
  def envoke_add_user(user, consent_description = "Express consent given on a NeuroHub or CBRAIN portal signup.")

    # return unless user.maillist_consent == "Yes"
    #
    uri          = URI.parse("#{envoke_api_base}/contacts")
    http         = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    data         = {
        "email"               => user.email,
        "first_name"          => guess_first_name(user),
        "last_name"           => guess_second_name(user),
        "consent_description" => consent_description,
        "interests" => {
           "Monthly newsletter": "Set"
        },
        "consent_status"      => "Express"
    }
    # binding.pry
    req      = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    req.body = data.to_json
    #uri.port = 433
    req.basic_auth envoke_id, envoke_key
    begin

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end
      if res.code == "400" && envoke_contact_with_email(user.email)
          cb_error "user with #{user.email} email is already in the maillist"
          # todo check is user active? if not add with new status?
      elsif ! res.code.start_with?('2')
        cb_error "Envoke opt in failed"
        user.add_log("Envoke opt in failed code #{res.code}  #{res.body}")
        # todo check is user active? if not add with new status?

      end
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
        Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      cb_error(e.message)
    end

    JSON.parse(res.body)['result_data']['id'] if res&.code&.start_with?("2")
  end

  # updates envoke contact
  def envoke_update(user, new_params, validate=true)
    contact_params =  envoke_contact_with_email(user.email)
    #validation
    binding.pry
    if validate
      return cb_error('Your email is not found in Envoke contact list, contact admin')  if ! contact_params
      return cb_error('is not boarded to Enovoke via NeuroHub signup, contact admin')  if user.envoke_id.blank?
    end

    # user.envoke_id = envoke_contact_with_email.dig('id') unless user.envoke_id # should we set user if alreday there?
    # user.envoke_id = envoke_add_user(user)
    uri          = URI.parse("#{envoke_api_base}/contacts/#{user.envoke_id}")
    http         = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req          = Net::HTTP::Patch.new(uri.path, 'Content-Type' => 'application/json')
    req.body     = new_params.to_json
    #uri.port = 433
    req.basic_auth envoke_id, envoke_key
    begin
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
        Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      cb_error(e.message)
    end
    if res&.code&.start_with?("2")
      JSON.parse(res.body)['result_data']['id']
    else
      cb_error('Newsletter contact list update failed')
    end
  end

  def envoke_opt_out(user) # opt out existing contact
    envoke_update(user,
      {"consent_status" => "Revoked",
       "consent_description" => "Revoked from NeuroHub account management page",
      "interests" => {"Monthly newsletter": "Unset"}
      })
  end

  #included again
  def envoke_reopt_in(user)
      envoke_update(user, {"consent_status" => "Express",
                           "interests" => { "Monthly newsletter": "Unset"   },
                           "consent_description" => "Reenabled from NeuroHub account management page"})
  end


  # deletes users ( not permitted)

  # finds a contact with a given email
  def envoke_contact_with_email(email)
    uri          = URI.parse("#{envoke_api_base}/contacts")
    uri.query = URI.encode_www_form({'filter[email]' => email})
    http         = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req          = Net::HTTP::Get.new(uri)
    # cbrain validates email, but consider to filter with CGI::escape or .
    #  note URI::encode might have unicode issues eg. see
    #  https://stackoverflow.com/questions/6714196/how-to-url-encode-a-string-in-ruby
    # uri.port = 433
    #
    req.basic_auth envoke_id, envoke_key

    begin
      #binding.pry
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
        # todo check is he active? if not add with new status?
      end
      binding.pry
      if res&.code&.start_with?("2")
        r = JSON.parse(res.body)
        cb_error('malformed Json from Envoke') && nil unless r.instance_of? Array
        r.dig(0)
      else
          nil          # cb_error("Unable to retrieve a contact with email")
      end

    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      flash['notice'] = ("Unable to retrieve a contact Envoke newsletter service #{e.message}")
    end
  end

  # delete contact, is not always allowed for api
  def envoke_delete_user(user)

    # return unless user.maillist_consent == "Yes"
    uri          = URI.parse("#{envoke_api_base}/contacts/#{user.envoke_id}")
    http         = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req          = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    #uri.port = 433
    req.basic_auth envoke_id, envoke_key
    begin
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end
    rescue StandardException => e
      cb_error(e.message)
    end
  end

  def send_mail_serge
    v = 'v4legacy'

    html = '<p>Hello world!</p>'

    data = [
        'SendEmails' => [
            [
                'EmailDataArray' => [
                    [
                        'email' => [
                            # Message fields...
                            [
                                "to_email"   => "serge.boroday@gmail.com",
                                "to_name"    => "Serge",
                                "from_email" => "info@neurohub.com",
                                # "from_name" => "me",
                                "message_subject" => "hello from envoke",
                                "message_html"    => html,
                            ]
                        ]
                    ]
                ]
            ]
        ]
    ]

    uri = URI.parse('https://e1.envoke.com/api/v4legacy/send/SendEmails')

    http     = Net::HTTP.new(uri.host, uri.port)
    req      = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    req.body = data.to_json
    #uri.port = 433
    http.use_ssl = true
    # might need this as well?
    # http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    req.basic_auth envoke_id, envoke_key
    puts uri.host, uri.port
    # res = http.request(req)
    # puts "response #{res.body} #{res.code}"
    # end

    # {param1: 'some value', param2: 'some other value'}.to_json
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

  end

end
