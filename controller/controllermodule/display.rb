class ControllerModuleDisplay < ControllerModule
	def initialize(name)
		super(name)
		defineCommand("clear")
		defineCommand("display")
		defineCommand("connected")
	end

	#---------------------------------------------
	# Implemented commands
	#---------------------------------------------
	# Returns detectorID
	def clear(optionJSON)
		if()
		return {status: "ok", detectorID: controller.detectorID}.to_json
	end
	alias detectorID id

	# Returns IP address
	def ip(optionJSON)
		# First, search for WiFi I/F.
		# If no WiFi interface with IP address assigned is found,
		# then proceed to the wired connection
		ifNames = ["wlan0", "eth0"]
		ifNames.each(){|ifName|
			ifAddrresses = Socket.getifaddrs.select{|x| (x.name == ifName) and x.addr.ipv4?}
			if(ifAddrresses!=nil and ifAddrresses.length!=0)then
				ip = ifAddrresses.first.addr.ip_address
				return {status: "ok", ip: ip}.to_json
			end
		}
		# If nothing is found, return empty string		
		return {status: "error", message: "IP address not assigned"}.to_json
	end

	# Returns git repo hash
	def hash(optionJSON)
		if(File.exist?(GROWTHRepository))then
			g = Git.open(GROWTHRepository)
			return {status: "ok", hash: g.log()[-1].sha}.to_json
		else
			return {status: "error", message: "GRWOTH git repository '#{GROWTHRepository}' not found "}.to_json
		end
	end

	# Reply to ping
	def ping(optionJSON)
		return {status: "ok", time: Time.now}.to_json
	end
end