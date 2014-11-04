require 'nest_thermostat/nest/structure'

module NestThermostat
  class Nest
    class Device
      attr_accessor :structure, :id, :name

      def initialize(structure:, id:, name:)
        @structure, @id, @name = structure, id, name
      end
    end
  end
end
