require 'nest_thermostat/nest/structure'
require 'nest_thermostat/nest/device'
require 'rubygems'
require 'httparty'
require 'json'
require 'uri'

module NestThermostat
  class Nest
    attr_accessor :email, :password, :login_url, :user_agent, :auth,
      :login, :token, :user_id, :transport_url,
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

      structure_ids   = status['structure'].keys
      devices_ids     = status['device'].keys

      @structures = structures_hash.map do |id, hash|
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

    def find_by_name(collection, name)
      collection.detect { |item| item.name == name }
    end

    def find_device(device_name)
      find_by_name(devices, device_name)
    end

    def find_structure(structure_name)
      find_by_name(structures, structure_name)
    end

    def find_many_by_name(collection, name)
      collection.detect { |item| item.name == name }
    end

    def find_devices(device_name)
      find_many_by_name(devices, device_name)
    end

    def find_structures(structure_name)
      find_many_by_name(structures, structure_name)
    end

    def devices
      structures.map(&:devices).flatten
    end

    def leaf
      device_info["leaf"]
    end

    #private

    def perform_login
      login_request = HTTParty.post(
                        login_url,
                        body:    { username: email, password: password },
                        headers: { 'User-Agent' => user_agent }
                      )

      self.auth ||= JSON.parse(login_request.body) rescue nil
      raise 'Invalid login credentials' if auth.has_key?('error') && auth['error'] == "access_denied"
    end

    def structures_hash
      ids = status['structure'].keys
      structures = {}
      ids.each { |id| structures[id] = structure_info(structure_id: id) }
      structures
    end

    def structure_info(structure_id: @structure_id)
      status['structure'][structure_id]
    end

    def devices_hash(ids: nil)
      ids = status['shared'].keys unless ids
      devices = {}
      ids.each { |id| devices[id]= shared_info(device_id: id) }
      devices
    end

    def user_info
      status['user'][user_id]
    end

    def device_info(device_id:)
      status["device"][device_id]
    end

    def shared_info(device_id:)
      status['shared'][device_id]
    end

  end
end
