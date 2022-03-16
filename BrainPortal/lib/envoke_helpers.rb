
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
module GlobusHelpers

  Revision_info = CbrainFileRevision[__FILE__] #:nodoc:


  require 'uri'
  require 'net/http'
  require 'json'
  require 'cgi'


  @envoke_id      = ENV['envoke_id']
  @envoke_auth    = ENV['envoke_auth']



  ENVOKE_API_BASE = 'https://e1.envoke.com/v1'

  def mail_cloud_setup?
    true if @envoke_id && @envoke_auth
  end

  def guess_first_name(user) # figure from sign up or guess first name
    signup = user.signup
    return signup.first_name if user.signup && user.signup.first_name && user.full_name.start_with?(user.signup.first)
    return user.full_name&.split(' ', 2)[0].presence # user might changed name
  end

  def guess_second_name(user) # figure from sign up or guess last name from the full name
    signup = user.signup
    return signup.last if signup && user.signup.last && user.full_name.end_with?(signup.last)
    first = guess_first_name(user)
    return "" if first == signup&.full_name
    return user.full_name&.split(first + ' ', 2)[1].presence if user.full_name.start_with?(first + ' ')
    return user.full_name.split[1].presence
  end

  # def names  # todo merge two methods?
  #   first
  #
  #   signup = user.signup
  #   return signup.first_name if user.signup && user.signup.first_name && user.full_name.start_with?(user.signup.first)
  #   first = gue
  #   return user.full_name&.split(guess' ', 1)[1] # user might changed name
  # end

  def envoke_add_user(user, consent_description = "Express consent given on website signup.")

    # return unless user.maillist_consent == "Yes"
    uri  = URI.parse("#{ENVOKE_API_BASE}/contacts")
    data = {
        "email"               => user.email,
        "first_name"          => guess_first_name(user),
        "last_name"           => guess_second_name(user),
        "consent_description" => consent_description,
        "consent_status"      => "Express"
    }

    http         = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req          = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    req.body     = data.to_json
    #uri.port = 433
    req.basic_auth @envoke_id, @envoke_auth

    req2      = Net::HTTP::Get.new(URI.parse("#{ENVOKE_API_BASE}/contacts/filter[email]={}"))
    req2.body = data.to_json
    #uri.port = 433
    req2.basic_auth @envoke_id, @envoke_auth


    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|

      http.request(req)
    end
    if res.code == "400"

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        res = http.request(req2)
        cb_error "user with #{user.email} email is already in the maillist"
        # todo check is he active? if not add with new status?
      end
    end
    JSON.parse(res.body)['result_data']['id'] if res.code.start_with?("2") rescue nil
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
                              "to_email" => "serge.boroday@gmail.com",
                              "to_name" => "Serge",
                              "from_email" => "info@neurohub.com",
                              # "from_name" => "me",
                              "message_subject" => "hello from envoke",
                              "message_html" => html,
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

   req.basic_auth envoke_id, envoke_auth
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
