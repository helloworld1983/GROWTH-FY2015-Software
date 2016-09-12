require "growth_controller/controller_module"

module GROWTH

class ControllerModuleDetector < ControllerModule
	
	def initialize(name)
		super(name)
		define_command("id")
		define_command("ip")
		define_command("hash")
		define_command("ping")
	end

	#---------------------------------------------
	# Implemented commands
	#---------------------------------------------
	# Returns detectorID
	def id(option_json)
		return {status: "ok", detector_id: controller.detector_id}.to_json
	end
	alias detector_id id

	# Returns IP address
	def ip(option_json)
		# First, search for WiFi I/F.
		# If no WiFi interface with IP address assigned is found,
		# then proceed to the wired connection
		interface_names = ["wlan0", "eth0"]
		interface_names.each(){|ifName|
			interface_addrresses = Socket.getifaddrs.select{|x| (x.name == ifName) and x.addr.ipv4?}
			if(interface_addrresses!=nil and interface_addrresses.length!=0)then
				ip = interface_addrresses.first.addr.ip_address
				return {status: "ok", ip: ip}.to_json
			end
		}
		# If nothing is found, return empty string		
		return {status: "error", message: "IP address not assigned"}.to_json
	end

	# Returns git repo hash
	def hash(option_json)
		if(File.exist?(GROWTH::GROWTH_REPOSITORY))then
			g = Git.open(GROWTH::GROWTH_REPOSITORY)
			return {status: "ok", hash: g.log()[-1].sha}.to_json
		else
			return {status: "error", message: "GRWOTH git repository '#{GROWTH::GROWTH_REPOSITORY}' not found "}.to_json
		end
	end

	# Reply to ping
	def ping(option_json)
		return {status: "ok", time: Time.now}.to_json
	end
end

end
