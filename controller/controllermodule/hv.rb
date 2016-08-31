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

		else
			# FY2016 onwards HV on command

		end
		# Return message
		return {status: "ok"}.to_json
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

		else
			# FY2016 onwards HV off command
			
		end
		# Return message
		return {status: "ok"}.to_json
	end
end