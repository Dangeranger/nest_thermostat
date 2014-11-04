require 'nest_thermostat/nest/structure'
require 'nest_thermostat/nest/device'
require 'rubygems'
require 'httparty'
require 'json'
require 'uri'

module NestThermostat
  class Nest
    attr_accessor :email, :password, :login_url, :user_agent, :auth,
      :temperature_scale, :login, :token, :user_id, :transport_url,
      :transport_host, :structures, :devices, :headers

    def initialize(config = {})

      # User specified information
      @email             = config[:email] || ENV['NEST_EMAIL'] || raise("please set email in NEST_EMAIL")
      @password          = config[:password] || ENV['NEST_PASSWORD'] || raise("please set nest password in NEST_PASSWORD")
      @login_url         = config[:login_url] || 'https://home.nest.com/user/login'
      @user_agent        = config[:user_agent] ||'Nest/1.1.0.10 CFNetwork/548.0.4'

      # Login and get token, user_id and URLs
      perform_login
      @token          = @auth["access_token"]
      @user_id        = @auth["userid"]
      @transport_url  = @auth["urls"]["transport_url"]
      @transport_host = URI.parse(transport_url).host
      @headers = {
        'Host'                  => transport_host,
        'User-Agent'            => user_agent,
        'Authorization'         => 'Basic ' + token,
        'X-nl-user-id'          => user_id,
        'X-nl-protocol-version' => '1',
        'Accept-Language'       => 'en-us',
        'Connection'            => 'keep-alive',
        'Accept'                => '*/*'
      }

      # Sets the value of @status to the result of refresh
      refresh

      # @structure  = config[:structure_id] || user_info['structures'][0].split('.')[1]
      # @device     = config[:device_id] || structure_info['devices'][0].split('.')[1]

      structure_ids   = status['structure'].keys
      devices_ids     = status['device'].keys

      @structures = find_structures.map do |id, hash|
        Structure.new(nest: self,
                      id: id,
                      name: hash['name']
                     )
      end
    end

    def refresh
      url = "#{transport_url}/v2/mobile/user.#{user_id}"
      request = HTTParty.get(url, headers: headers)
      result = JSON.parse(request.body)

      @status = result
    end

    attr_reader :status

    def leaf
      device_info["leaf"]
    end

    # private
    def perform_login
      login_request = HTTParty.post(
                        login_url,
                        body:    { username: email, password: password },
                        headers: { 'User-Agent' => user_agent }
                      )

      self.auth ||= JSON.parse(login_request.body) rescue nil
      raise 'Invalid login credentials' if auth.has_key?('error') && auth['error'] == "access_denied"
    end

    def find_structures
      ids = status['structure'].keys
      structures = {}
      ids.each { |id| structures[id] = structure_info(structure_id: id) }
      structures
    end

    def structure_info(structure_id: @structure_id)
      status['structure'][structure_id]
    end

    def find_devices(ids: nil)
      ids = status['shared'].keys unless ids
      devices = {}
      ids.each { |id| devices[id]= device_info(device_id: id) }
      devices
    end

    def user_info
      status['user'][user_id]
    end

    def device_info(device_id: @device_id)
      status["device"][device_id]
    end

  end
end
