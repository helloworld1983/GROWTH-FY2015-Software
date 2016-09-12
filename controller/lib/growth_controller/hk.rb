require "growth_io/slowadc"
require "rpi"

class ControllerModuleHK < ControllerModule

	# I2C bus number to be used
	BME280_I2C_BUS_NUMBER = 1

	def initialize(name)
		super(name)
		define_command("read")
		
		# Construct I2C object and BME280 object
		@i2cbus = RPi::I2CBus.new(BME280_I2C_BUS_NUMBER)
		@bme = RPi::BME280.new(i2cbus)
	end

	def read(option_json)
		# Read SlowADC (current, PCB temperature)
		slowadc_result = {}
		begin
			slowadc_result = SlowADC.read()
		rescue
			return {status: "error", message: "SlowADC read failed"}.to_json
		end

		# Read from BME280
		bme280_result = {}
		begin
			@bme.update
			bme280_result = {
				temperature: {value:@bme.temperature, units:"degC"},
				pressure: {value:@bme.pressure, units:"mb"},
				humidity: {value:@bme.humidity, units:"%"}
			}
		rescue
			return {status: "error", message: "BME280 read failed"}.to_json
		end

		# Return result
		time = Time.now
		return {status: "ok", unixtime:time.to_i, time:time.strftime("%Y-%m-%dT%H-%M-%S") hk: {slow_adc:slowadc_result, bme280:bme280_result}}.to_json
	end
end