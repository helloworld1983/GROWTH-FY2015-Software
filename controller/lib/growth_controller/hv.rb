require "growth_if/slowdac"
require "growth_if/gpio"

module GROWTH

class ControllerModuleHV < ControllerModule
	HV_CHANNEL_LOWER = 0
	HV_CHANNEL_UPPER = 3

	HV_VALUE_IN_MILLI_VOLT_LOWER = 0
	HV_VALUE_IN_MILLI_VOLT_UPPER = 3300

	def initialize(name)
		super(name)
		define_command("on")
		define_command("off")
	end

	def is_fy2015()
		if(@controller.detector_id.include?("growth-fy2015"))then
			return true
		else
			return false
		end
	end

	def on(option_json)
		# Check option
		if(option_json["ch"]==nil)then
			return {status: "error", message: "hv.on command requires channel option"}.to_json
		end
		# Parse channel option and value_in_mV option
		ch = option_json["ch"].to_i
		if(ch<HV_CHANNEL_LOWER or ch>HV_CHANNEL_UPPER)then
			return {status: "error", message: "Invalid channel index #{ch}"}.to_json
		end
		# Turn on HV
		if(is_fy2015())then
			# FY2015 HV on command
			`hv_on`
		else
			# FY2016 onwards HV on command
			if(option_json["value_in_mV"]==nil)then
				return {status: "error", message: "hv.on command requires DAC output voltage in mV"}.to_json
			end
			# Check value range
			value_in_mV = option_json["value_in_mV"]
			if(value_in_mV<HV_VALUE_IN_MILLI_VOLT_LOWER or value_in_mV>HV_VALUE_IN_MILLI_VOLT_UPPER)then
				return {status: "error", message: "hv.on command received invalid 'voltage in mV' of #{value_in_mV}"}.to_json
			end
			# Set HV value
			if(!GROWTH.SlowDAC.set_output(ch, value_in_mV))then
				return {status: "error", message: "hv.on command failed to set DAC output voltage (SPI error?)"}.to_json
			end
			# Turn on HV output
			GROWTH.GPIO.set_hv(ch,:on)
		end
		# Return message
		return { #
			status: "ok", message:"hv.on executed", ch:option_json["ch"].to_i, #
			value_in_mV:value_in_mV.to_i}.to_json
	end

	def off(option_json)
		# Check option
		if(option_json["ch"]==nil)then
			return {status: "error", message: "hv.off command requires channel option"}.to_json
		end
		# Parse channel option
		ch = option_json["ch"].to_i
		if(ch<HV_CHANNEL_LOWER or ch>HV_CHANNEL_UPPER)then
			return {status: "error", message: "Invalid channel index #{ch}"}.to_json
		end
		# Turn off HV
		if(is_fy2015())then
			# FY2015 HV off command
			`hv_off`
		else
			# FY2016 onwards HV off command
			# Set HV value (0 mV)
			GROWTH.SlowDAC.set_output(ch, 0)
			# Turn off HV output
			GROWTH.GPIO.set_hv(ch,:off)
		end
		# Return message
		return {status: "ok", message:"hv.off executed", ch:option_json["ch"].to_i}.to_json
	end
end

end
