require 'nest_thermostat/nest/structure'

module NestThermostat
  class Nest
    class Device
      attr_accessor :structure, :id, :name, :temperature_scale

        def initialize(structure:, id:, name:, temperature_scale: "f")
        @structure, @id, @name, @temperature_scale = structure, id, name, temperature_scale
      end

      def leaf
        device_info["leaf"]
      end

      def fan_mode
        device_info["fan_mode"]
      end

      def fan_mode=(state)
        HTTParty.post(
          "#{structure.nest.transport_url}/v2/put/device.#{id}",
          body: %Q({"fan_mode":"#{state}"}),
          headers: structure.nest.headers
        )
        structure.nest.refresh
      end

      def device_info
        status["device"][id]
      end

      def track_info
        status["track"][id]
      end

      def public_ip
        track_info["last_ip"].strip
      end

      def status
        structure.status
      end

      def humidity
        device_info["current_humidity"]
      end

      def temperature
        convert_temp_for_get(shared_info["target_temperature"])
      end
      alias_method :temp, :temperature

      def temperature=(degrees)
        degrees = convert_temp_for_set(degrees)

        request = HTTParty.post(
          "#{structure.nest.transport_url}/v2/put/shared.#{id}",
          body: %Q({"target_change_pending":true,"target_temperature":#{degrees}}),
          headers: structure.nest.headers
        )
        structure.nest.refresh
      end
      alias_method :temp=, :temperature=

      def current_temperature
        convert_temp_for_get(shared_info["current_temperature"])
      end
      alias_method :current_temp, :current_temperature

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

      def target_temperature_at
        epoch = device_info["time_to_target"]
        epoch != 0 ? Time.at(epoch) : false
      end
      alias_method :target_temp_at, :target_temperature_at

      def temp_scale=(scale)
        @temperature_scale = scale
        structure.nest.refresh
      end

      def c2f(degrees)
        degrees.to_f * 9.0 / 5 + 32
      end

      def f2c(degrees)
        (degrees.to_f - 32) * 5 / 9
      end

      def k2c(degrees)
        degrees.to_f - 273.15
      end

      def c2k(degrees)
        degrees.to_f + 273.15
      end

      def shared_info
        status["shared"][id]
      end

    end
  end
end
