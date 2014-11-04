require 'dotenv'
require 'pry'
require 'nest_thermostat'

Dotenv.load
RSpec.configure do |c|
    c.filter_run focus: true
    c.run_all_when_everything_filtered = true
end

describe NestThermostat::Nest do # TODO make mock for connection
  before(:all) do
    @nest = NestThermostat::Nest.new({temperature_scale: 'F'})
  end

  it "logs in to home.nest.com" do
    @nest.transport_url.should match /transport.home.nest.com/
  end

  it "detects invalid logins" do
    expect { NestThermostat::Nest.new({email: 'invalid@example.com', password: 'asdf'})
    }.to raise_error
  end

  it "gets the status" do
    @nest.status['device'].first[1]['mac_address'].should match /(\d|[a-f]|[A-F])+/
  end

  it "gets the public ip address" do
    first_device.public_ip.should match /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})?$/
  end

  let(:first_structure) { @nest.structures[0] }
  let(:first_device) { first_structure.devices[0] }

  it "gets the leaf status" do
    first_device.leaf.should_not be_nil
  end

  it "gets away status" do
    first_structure.away.should_not be_nil
  end

  it "sets away status" do
    first_structure.away = true
    first_structure.away.should == true
    first_structure.away = false
    first_structure.away.should == false
  end

  it "gets the current temperature" do
    first_device.current_temperature.should be_a_kind_of(Numeric)
    first_device.current_temp.should be_a_kind_of(Numeric)
  end

  it "gets the relative humidity" do
    first_device.humidity.should be_a_kind_of(Numeric)
  end

  it "gets the temperature" do
    first_device.temperature.should be_a_kind_of(Numeric)
    first_device.temp.should be_a_kind_of(Numeric)
  end

  it "sets the temperature" do
    first_device.temp = '74'
    first_device.temp.round.should eq(74)

    first_device.temperature = '73'
    first_device.temperature.round.should eq(73)
  end

  it "sets the temperature in celsius" do
    @nest.temperature_scale = 'c'
    first_device.temperature = '22'
    first_device.temperature.should eq(22.0)
  end

  it "sets the temperature in kelvin" do
    @nest.temperature_scale = 'k' #added this line
    first_device.temp_scale = 'k'
    first_device.temperature = '296'
    first_device.temperature.should eq(296.0)
  end

  it "gets the target temperature time" do
    first_device.target_temp_at.should_not be_nil # (DateObject or false)
    first_device.target_temperature_at.should_not be_nil # (DateObject or false)
  end

  it "gets the fan status" do
    %w(on auto).should include first_device.fan_mode
  end

  it "sets the fan mode" do
    first_device.fan_mode = "on"
    first_device.fan_mode.should == "on"
    first_device.fan_mode = "auto"
    first_device.fan_mode.should == "auto"
  end

  it "returns a list of structures on account" do
    @nest.structures.should_not be_nil
  end

  it "returns a list of devices on account" do
    first_structure.devices.should_not be_nil
  end


end
