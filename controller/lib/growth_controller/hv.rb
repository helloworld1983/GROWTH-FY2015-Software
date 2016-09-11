require "growth_io/slowdac"
require "growth_io/gpio"

class ControllerModuleHV < ControllerModule
	HVChannelLower = 0
	HVChannelUpper = 3
	def initialize(name)
		super(name)
		defineCommand("on")
		defineCommand("off")
	end

	def isFY2015()
		if(@controller.detectorID.include?("growth-fy2015"))then
			return true
		else
			return false
		end
	end

	def on(optionJSON)
		# Check option
		if(optionJSON["ch"]==nil)then
			return {status: "error", message: "hv.on command requires channel option"}.to_json
		end
		# Parse channel option
		ch = optionJSON["ch"].to_i
		if(ch<HVChannelLower or ch>HVChannelUpper)then
			return {status: "error", message: "Invalid channel index #{ch}"}.to_json
		end
		# Turn on HV
		if(isFY2015())then
			# FY2015 HV on command
			`hv_on`
		else
			# FY2016 onwards HV on command
			if(optionJSON["value_in_mV"]==nil)then
				return {status: "error", message: "hv.on command requires DAC output voltage in mV"}.to_json
			end
			# Set HV value
			if(!GROWTH.SlowDAC.set_output(ch, optionJSON["value_in_mV"]))then
				return {status: "error", message: "hv.on command failed to set DAC output voltage (SPI error?)"}.to_json
			end
			# Turn on HV output
			GROWTH.GPIO.set_hv(ch,:on)
		end
		# Return message
		return { #
			status: "ok", message:"hv.on executed", ch:optionJSON["ch"].to_i, #
			value_in_mV:optionJSON["value_in_mV"].to_i}.to_json
	end

	def off(optionJSON)
		# Check option
		if(optionJSON["ch"]==nil)then
			return {status: "error", message: "hv.off command requires channel option"}.to_json
		end
		# Parse channel option
		ch = optionJSON["ch"].to_i
		if(ch<HVChannelLower or ch>HVChannelUpper)then
			return {status: "error", message: "Invalid channel index #{ch}"}.to_json
		end
		# Turn off HV
		if(isFY2015())then
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
		return {status: "ok", message:"hv.off executed", ch:optionJSON["ch"].to_i}.to_json
	end
end