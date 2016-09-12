require "rbczmq"
require "json"
require "yaml"
require "socket"
require "logger"

require "growth_controller/controller_module"
require "growth_controller/detector"
require "growth_controller/hv"
require "growth_controller/display"

module GROWTH
	# Constants
	NO_M2X = true
	GROWTH_CONFIG_FILE = File.expand_path("~/growth_config.yaml")
	GROWTH_KEY_FILE    = ENV["GROWTH_KEY_FILE"]
	GROWTH_REPOSITORY  = ENV["GROWTH_REPOSITORY"]

	class DetectorController
		DETECTOR_CONTROLLER_ZMQ_PORT_NUMBER   = 10000
		LOG_MESSAGE_CONTROLLER_STARTED = "controller daemon started"
		LOG_MESSAGE_CONTROLLER_STOPPED = "controller daemon stopped"

		# Constructs an instance, and then start ZeroMQ server
		def initialize(detector_db_file)
			@logger = Logger.new(STDOUT)
			@logger.progname = "DetectorController"

			# Check constant definitions
			check_constants()

			# Initialize instance variables
			@stopped = false
			controller_modules = {}

			# Load detectorID from the YAML configuration file
			load_growth_config_file()

			# Load detectorDB from the specified JSON file
			load_detector_db(detector_db_file)

			# Start ZeroMQ server
			@context = ZMQ::Context.new
			@socket  = @context.socket(ZMQ::REP)
			@socket.bind("tcp://*:#{DETECTOR_CONTROLLER_ZMQ_PORT_NUMBER}")

			@logger.info "Controller started"

			# Add controller modules
			add_controller_module(GROWTH.ControllerModuleDetector.new("det"))
			add_controller_module(GROWTH.ControllerModuleHV.new("hv"))
			add_controller_module(GROWTH.ControllerModuleDisplay.new("display"))
			add_controller_module(GROWTH.ControllerModuleDisplay.new("hk"))
		end

		private
		def check_constants()
			{GROWTH_CONFIG_FILE: GROWTH_CONFIG_FILE,
				GROWTH_KEY_FILE: GROWTH_KEY_FILE,
				GROWTH_REPOSITORY: GROWTH_REPOSITORY
			}.each(){|label,file|
				if(file==nil or file=="")then
					@logger.fatal("#{label} environment variable not set")
					exit -1
				end
				if(!File.exists?(file))then
					@logger.fatal("#{label} #{file} not found")
					exit -1
				end
			}
		end

		# Load YAML configuration file, and set detectorID
		def load_growth_config_file()
			# Check file presence
			if(!File.exist?(GROWTH_CONFIG_FILE))then
				@logger.error "#{GROWTH_CONFIG_FILE} not found"
				exit -1
			end
			# Load YAML configuration file
			@logger.info "Loading #{GROWTH_CONFIG_FILE}"
			yaml = YAML.load_file(GROWTH_CONFIG_FILE)
			if(yaml["detectorID"]==nil or yaml["detectorID"]=="")then
				@logger.error "detectorID not found in #{GROWTH_CONFIG_FILE}"
				exit -1
			end
			# Set instance variable and dump the result
			@detector_id = yaml["detectorID"]
			@logger.info "detectorID: #{@detector_id}"
		end

		# Load detectorDB
		def load_detector_db(detector_db_file)
			# Load file
			json = JSON.parse(File.read(detector_db_file))
			@detector_db = json[@detector_id]
			if(@detector_db==nil)then
				@logger.error "detectorID #{@detector_id} is not defined in the detectorDB."
				exit -1
			end

			# Get M2X keys
			if(@detector_db["m2x"]==nil)then
				@logger.error "M2X keys are not preseent in the detectorDB."
				exit -1
			end
			@device_id = @detector_db["m2x"]["device-id"]
			@primary_endpoint = "/devices/#{@device_id}"
			@primary_api_key = @detector_db["m2x"]["primary-api-key"]
			
			# Get file output dir (event file and hk file will be saved in this directory)
			@outputDir =  @detector_db["storage"]["root-path"]
			if(@detector_db["storage"]==nil or @detector_db["storage"]["root-path"]==nil or @detector_db["storage"]["root-path"]=="")then
				@logger.error "'storage':{'root-path': 'path_to_output_dir'} should appear in the detectorDB."
				exit -1
			end

			# Send a log message to M2X
			send_log_to_m2x(LOG_MESSAGE_CONTROLLER_STARTED)
		end

		# Process received JSON command
		def process_json_command(json)
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
			@logger.info "Subsystem: #{subsystem} Command: #{command} Option: #{option}"

			# Controller commands
			if(command=="stop")then
				@stopped = true
				return {status: "ok", messaeg: "Controller has been stopped"}.to_json
			end

			# Subsystem commands
			if(controller_modules[subsystem]!=nil)then
				controller_module = controller_modules[subsystem]
				if(controller_module.has_command(command))then
					return controller_module.send(command, option)
				end
			else
				subsystem_not_found_message = {status: "error", message: "Subsystem '#{subsystem}' not found"}.to_json	
				return subsystem_not_found_message
			end

			# If command not found, return error message
			command_not_found_message = {status: "error", message: "Command '#{subsystem}.#{command}' not found"}.to_json
			return command_not_found_message
		end

		# Utility function to convert sting to JSON
		def to_json_object(str)
			return JSON.parse(str)
		end

		# Main loop
		def run()
			while(!@stopped)
				# Wait for a JSON message from a client
				message = @socket.recv()
				#@logger.info "Receive status: #{status} (#{ZMQ::Util.error_string}) message: #{message.inspect}"
				@logger.info "Receive status: message: #{message.inspect}"

				# Process JSON commands
				replyMessage = "{}"
				if(message!="")then
					replyMessage = process_json_command(to_json_object(message))
				end
				@socket.send(replyMessage)
			end
			# Finalize
			@logger.info "Controller stopped"
		end

		# Send log to M2X
		def send_log_to_m2x(str)
			if(NO_M2X)then
				return
			end

			stream_id = "detector-status"
			url = "http://api-m2x.att.com/v2/devices/#{@device_id}/streams/#{stream_id}/value"
			json = { value: str }.to_json
			@logger.info "URL = #{url}"
			@logger.info "json = #{json}"
			`curl -i -X PUT #{url} -H "X-M2X-KEY: #{@primary_api_key}" -H "Content-Type: application/json" -d "#{json.gsub('"','\"')}"`
		end

		# Add ControllerModule instance
		def add_controller_module(controller_module)
			controller_module.controller = self
			controller_modules[controller_module.name] = controller_module
			@logger.info "ControllerModule #{controller_module.name} added"
		end

		# Getter/setter
		attr_accessor :detector_id
	end
end
