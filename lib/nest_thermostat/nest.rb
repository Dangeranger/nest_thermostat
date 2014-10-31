require 'rubygems'
require 'httparty'
require 'json'
require 'uri'

module NestThermostat
  class Nest
    attr_accessor :email, :password, :login_url, :user_agent, :auth,
      :temperature_scale, :login, :token, :user_id, :transport_url,
      :transport_host, :structure_id, :device_id, :headers

    def initialize(config = {})

      # User specified information
      @email             = config[:email] || ENV['NEST_EMAIL'] || raise("please set email in NEST_EMAIL")
      @password          = config[:password] || ENV['NEST_PASSWORD'] || raise("please set nest password in NEST_PASSWORD")
      @temperature_scale = config[:temperature_scale] || config[:temp_scale] || 'f'
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

      @structure_id = config[:structure_id] || user_info['structures'][0].split('.')[1]
      @device_id    = config[:device_id] || structure_info['devices'][0].split('.')[1]

    end

    def refresh
      url = "#{transport_url}/v2/mobile/user.#{user_id}"
      request = HTTParty.get(url, headers: headers)
      result = JSON.parse(request.body)

      @status = result
    end

    attr_reader :status

    def public_ip
      track_info["last_ip"].strip
    end

    def leaf
      device_info["leaf"]
    end

    def humidity
      device_info["current_humidity"]
    end

    def current_temperature
      convert_temp_for_get(shared_info["current_temperature"])
    end
    alias_method :current_temp, :current_temperature

    def temperature
      convert_temp_for_get(shared_info["target_temperature"])
    end
    alias_method :temp, :temperature

    def temperature=(degrees)
      degrees = convert_temp_for_set(degrees)

      request = HTTParty.post(
        "#{transport_url}/v2/put/shared.#{device_id}",
        body: %Q({"target_change_pending":true,"target_temperature":#{degrees}}),
        headers: headers
      )
      refresh
    end
    alias_method :temp=, :temperature=

    def target_temperature_at
      epoch = device_info["time_to_target"]
      epoch != 0 ? Time.at(epoch) : false
    end
    alias_method :target_temp_at, :target_temperature_at

    def away
      status["structure"][structure_id]["away"]
    end

    def away=(state)
      request = HTTParty.post(
        "#{transport_url}/v2/put/structure.#{structure_id}",
        body: %Q({"away_timestamp":#{Time.now.to_i},"away":#{!!state},"away_setter":0}),
        headers: headers
      )
      refresh
    end

    def temp_scale=(scale)
      @temperature_scale = scale
      refresh
    end

    def fan_mode
      device_info["fan_mode"]
    end

    def fan_mode=(state)
      HTTParty.post(
        "#{transport_url}/v2/put/device.#{device_id}",
        body: %Q({"fan_mode":"#{state}"}),
        headers: headers
      )
      refresh
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

    def structures
      ids = user_info['structures'].map  { |struct| struct.split('.')[1] }
      structures = {}
      ids.each { |id| structures[id] = structure_info(structure_id: id) }
      structures
    end

    def structure_info(structure_id: @structure_id)
      status['structure'][structure_id]
    end

    def devices
      # Save this for another method #structure_devices(struct_id) ??
      # structures.each { |key, hash| ids.push(hash['devices']) }
      # ids = ids.flatten.map { |id| id.split('.')[1] }
      ids = status['device'].keys
      devices = {}
      ids.each { |id| devices[id]= device_info(device_id: id) }
      devices
    end

    def user_info
      status['user'][user_id]
    end

    def track_info
      status["track"][device_id]
    end

    def device_info(device_id: @device_id)
      status["device"][device_id]
    end

    def shared_info
      status["shared"][device_id]
    end

    def convert_temp_for_get(degrees)
      case temperature_scale
      when /[fF](ahrenheit)?/
        c2f(degrees).round(3)
      when /[kK](elvin)?/
        c2k(degrees).round(3)
      else
        degrees
      end
    end

    def convert_temp_for_set(degrees)
      case temperature_scale
      when /[fF](ahrenheit)?/
        f2c(degrees).round(5)
      when /[kK](elvin)?/
        k2c(degrees).round(5)
      else
        degrees
      end
    end

    def k2c(degrees)
      degrees.to_f - 273.15
    end

    def c2k(degrees)
      degrees.to_f + 273.15
    end

    def c2f(degrees)
      degrees.to_f * 9.0 / 5 + 32
    end

    def f2c(degrees)
      (degrees.to_f - 32) * 5 / 9
    end
  end
end
