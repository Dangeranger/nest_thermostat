require 'nest_thermostat/nest/device'

module NestThermostat
  class Nest
    class Structure
      attr_accessor :nest, :id, :devices, :name

      def initialize(id:, name:, nest:)
        @id, @name, @nest = id, name, nest
        @devices = @nest.devices_hash(ids: device_ids).map do |id, hash|
          Device.new(structure: self, id: id, name: hash['name'])
        end
      end

      def device_ids
        ids = []
        @nest.status['structure'].each do |key, hash|
          if key == @id
            ids << hash['devices'].map { |id| id.split('.')[1] }
          end
        end
        ids.flatten
      end

      def away
        status["structure"][id]["away"]
      end

      def away=(state)
        request = HTTParty.post(
          "#{nest.transport_url}/v2/put/structure.#{id}",
          body: %Q({"away_timestamp":#{Time.now.to_i},"away":#{!!state},"away_setter":0}),
          headers: nest.headers
        )
        nest.refresh
      end

      def status
        nest.status
      end

    end
  end
end
