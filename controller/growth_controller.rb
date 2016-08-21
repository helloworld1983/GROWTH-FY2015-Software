#!/usr/bin/env ruby
require "rbczmq"
require "json"
require "yaml"
require "socket"
require "git"

# 
# This program runs as a daemon on Raspberry Pi of the detector.
# The daemon acts as a ZeroMQ server and accepts ZeroMQ client connection.
# Clients send JSON commands to the server to controll the detector, 
# to start/stop data acquisition, and to retrieve internal status of the detector.
# 

# Constants
NoM2X = true
GROWTHConfig     = File.expand_path("~/growth_config.yaml")
GROWTHRepository = File.expand_path("~/git/GROWTH-FY2015-Software")

class ControllerModule
	def initialize(name)
		@controller = nil
		@name = name
		@commands = []
	end
	attr_accessor :controller, :name

	def defineCommand(name)
		@commands << name
	end

	def hasCommand(name)
		n = @commands.count(){|e| e==name }
		if(n!=0)then
			return true
		else
			return false
		end
	end
end

class ControllerModuleDetector < ControllerModule
	def initialize(name)
		super(name)
		defineCommand("id")
		defineCommand("ip")
		defineCommand("hash")
		defineCommand("ping")
	end

	#---------------------------------------------
	# Implemented commands
	#---------------------------------------------
	# Returns detectorID
	def id(optionJSON)
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


class DetectorController
	PortNumber   = 5555
	LogMessageControllerStarted = "controller daemon started"
	LogMessageControllerStopped = "controller daemon stopped"

	# Constructs an instance, and then start ZeroMQ server
	def initialize(detectorDBFile)
		# Initialize instance variables
		@stopped = false
		@controllerModules = {}

		# Load detectorID from the YAML configuration file
		loadGROWTHConfigFile()

		# Load detectorDB from the specified JSON file
		@detectorDBFile = detectorDBFile
		loadDetectorDB(detectorDBFile)

		# Start ZeroMQ server
		@context = ZMQ::Context.new
		@socket  = @context.socket(ZMQ::REP)
		@socket.bind("tcp://*:#{PortNumber}")

		puts "Controller started"
	end

	# Load YAML configuration file, and set detectorID
	def loadGROWTHConfigFile()
		# Check file presence
		if(!File.exist?(GROWTHConfig))then
			STDERR.puts "Error: #{GROWTHConfig} not found"
			exit -1
		end
		# Load YAML configuration file
		puts "Loading #{GROWTHConfig}"
		yaml = YAML.load_file(GROWTHConfig)
		if(yaml["detectorID"]==nil or yaml["detectorID"]=="")then
			STDERR.puts "Error: detectorID not found in #{GROWTHConfig}"
			exit -1
		end
		# Set instance variable and dump the result
		@detectorID = yaml["detectorID"]
		puts "detectorID: #{@detectorID}"
	end

	# Load detectorDB
	def loadDetectorDB(detectorDBFile)
		# Load file
		json = JSON.parse(File.read(detectorDBFile))
		@detectorDB = json[@detectorID]
		if(@detectorDB==nil)then
			STDERR.puts "Error: detectorID #{@detectorID} is not defined in the detectorDB."
			exit -1
		end

		# Get M2X keys
		if(@detectorDB["m2x"]==nil)then
			STDERR.puts "Error: M2X keys are not preseent in the detectorDB."
			exit -1
		end
		@device_id = @detectorDB["m2x"]["device-id"]
		@primary_endpoint = "/devices/#{@device_id}"
		@primary_api_key = @detectorDB["m2x"]["primary-api-key"]
		
		# Get file output dir (event file and hk file will be saved in this directory)
		@outputDir =  @detectorDB["storage"]["root-path"]
		if(@detectorDB["storage"]==nil or @detectorDB["storage"]["root-path"]==nil or @detectorDB["storage"]["root-path"]=="")then
			STDERR.puts "Error: 'storage':{'root-path': 'path_to_output_dir'} should appear in the detectorDB."
			exit -1
		end

		# Send a log message to M2X
		sendLogToM2X(LogMessageControllerStarted)
	end

	# Process received JSON command
	def processJSONCommand(json)
		# Parse message
		subsystem="controller"
		command=json["command"].strip
		option={}
		if(json["option"]!=nil)then
			option=json["option"]
		end
		if(command.include?("."))then
			subsystem = command.split(".")[0]
			command = command.split(".")[1]
		end
		puts "Subsystem: #{subsystem} Command: #{command} Option: #{option}"

		# Controller commands
		if(command=="stop")then
			@stopped = true
			return {"status": "ok", "messaeg": "Controller has been stopped"}.to_json
		end

		# Subsystem commands
		if(@controllerModules[subsystem]!=nil)then
			controllerModule = @controllerModules[subsystem]
			if(controllerModule.hasCommand(command))then
				return controllerModule.send(command, option)
			end
		else
			subsystemNotFoundMessage = {"status": "error", "message": "Subsystem '#{subsystem}' not found"}.to_json	
			return subsystemNotFoundMessage
		end

		# If command not found, return error message
		commandNotFoundMessage = {"status": "error", "message": "Command '#{subsystem}.#{command}' not found"}.to_json
		return commandNotFoundMessage
	end

	# Utility function to convert sting to JSON
	def toJSONObject(str)
		return JSON.parse(str)
	end

	# Main loop
	def run()
		while(!@stopped)
			# Wait for a JSON message from a client
			message = @socket.recv()
			#puts "Receive status: #{status} (#{ZMQ::Util.error_string}) message: #{message.inspect}"
			puts "Receive status: message: #{message.inspect}"

			# Process JSON commands
			replyMessage = "{}"
			if(message!="")then
				replyMessage = processJSONCommand(toJSONObject(message))
			end
			@socket.send(replyMessage)
		end
		# Finalize
		puts "Controller stopped"
	end

	# Send log to M2X
	def sendLogToM2X(str)
		if(NoM2X)then
			return
		end

		stream_id = "detector-status"
		url = "http://api-m2x.att.com/v2/devices/#{@device_id}/streams/#{stream_id}/value"
		json = { "value": str }.to_json
		puts "URL = #{url}"
		puts "json = #{json}"
		`curl -i -X PUT #{url} -H "X-M2X-KEY: #{@primary_api_key}" -H "Content-Type: application/json" -d "#{json.gsub('"','\"')}"`
	end

	# Add ControllerModule instance
	def addControllerModule(controllerModule)
		controllerModule.controller = self
		@controllerModules[controllerModule.name] = controllerModule
		puts "ControllerModule #{controllerModule.name} added"
	end

	# Getter/setter
	attr_accessor :detectorID

end


controller = DetectorController.new("detectorDB.json")
controller.addControllerModule(ControllerModuleDetector.new("det"))
controller.addControllerModule(ControllerModuleHV.new("hv"))
controller.run()
