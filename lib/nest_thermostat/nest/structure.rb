require 'nest_thermostat/nest/device'

module NestThermostat
  class Nest
    class Structure
      attr_accessor :nest, :id, :devices, :name

      def initialize(nest:, id:, name:)
        @nest, @id, @name = nest, id, name
        @devices = @nest.find_devices(ids: device_ids).map do |id, hash|
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

    end
  end
end
