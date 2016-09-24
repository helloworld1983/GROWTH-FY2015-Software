require "growth_if/slowadc"
require "growth_if/gpio"
require "rpi"

module GROWTH

class ControllerModuleHK < ControllerModule

	# I2C bus number to be used
	BME280_I2C_BUS_NUMBER = 1

	def initialize(name)
		super(name)
		define_command("read")
		
		@logger = Logger.new(STDOUT)
		@logger.progname = "ControllerModuleHK"

		# Construct I2C object and BME280 object
		@i2cbus = RPi::I2CBus.new(BME280_I2C_BUS_NUMBER)
		@bme=nil
		open_bme280()
	end

	private
	def open_bme280()
		begin
			@logger.info("Opening BME280...")
			@bme = RPi::BME280.new(@i2cbus)
			@logger.info("BME280 successfully opened")
			return true
		rescue => e
			@logger.warn("I2C communication with BME280 returned error (#{e}). Perhaps BME280 is not connected.")
			@bme = nil
			return false
		end
	end

	def read(option_json)
		# Read SlowADC (current, PCB temperature)
		slowadc_result = {}
		begin
			slowadc_result = SlowADC.read()
		rescue => e
			@logger.error("Slow ADC read failed (#{e})")
			return {status: "error", message: "SlowADC read failed (#{e})"}
		end

		# Read from BME280
		bme280_result = {}
		for trial in 0...5 do
			if (@bme == nil) then
				# If not connected, try to connect to BME280
				if(open_bme280() == false) then
					@logger.warn("Continue without BME280 (trial #{trial})") 
				end
			end

			# If successfully opened, continue to read
			bme_read_succeeded = false
			if (@bme != nil) then
				begin
					@bme.update
					bme_read_succeeded = true
				rescue => e
					@logger.error("BME280 read error (trial #{trial}) (#{e})")
					@bme = nil
				end
				
				if bme_read_succeeded == true and @bme != nil then
					@logger.debug("BME280 read successful (trial #{trial})")
					bme280_result = {
						temperature: {value:@bme.temperature, units:"degC"},
						pressure: {value:@bme.pressure, units:"mb"},
						humidity: {value:@bme.humidity, units:"%"}
					}
					break
				end
			end
		end

		# GPIO
		slide_switch_status = ""
		if(GPIO.is_slide_switch_on?())then
			slide_switch_status = "on"
		else
			slide_switch_status = "off"
		end

		# Return result
		time = Time.now
		return {
			status: "ok", unixtime:time.to_i, time:time.strftime("%Y-%m-%dT%H-%M-%S"),
			hk: {slow_adc:slowadc_result, bme280:bme280_result, slide_switch: slide_switch_status}
		}
	end
end

end
