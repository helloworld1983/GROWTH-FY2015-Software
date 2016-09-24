require "rbczmq"
require "json"
require "yaml"
require "socket"
require "logger"

require "growth_controller/controller_module"
require "growth_controller/detector"
require "growth_controller/hv"
require "growth_controller/display"
require "growth_controller/hk"

module GROWTH
  # Constants
  USE_M2X = false
  GROWTH_CONFIG_FILE = File.expand_path("~/growth_config.yaml")
  GROWTH_KEY_FILE    = ENV["GROWTH_KEY_FILE"]
  GROWTH_REPOSITORY  = ENV["GROWTH_REPOSITORY"]

  class DetectorController
    DETECTOR_CONTROLLER_ZMQ_PORT_NUMBER   = 10000
    LOG_MESSAGE_CONTROLLER_STARTED = "controller daemon started"
    LOG_MESSAGE_CONTROLLER_STOPPED = "controller daemon stopped"

    # Constructs an instance, and then start ZeroMQ server
    def initialize()
      @logger = Logger.new(STDOUT)
      @logger.progname = "DetectorController"

      # Use M2X telemetry logging?
      @use_m2x = USE_M2X

      # Check constant definitions
      check_constants()

      # Initialize instance variables
      @stopped = false
      @controller_modules = {}

      # Load detector configuration file and M2X keys
      load_growth_config_file()
      if(USE_M2X)then
        load_keys()
      end

      # Start ZeroMQ server
      @context = ZMQ::Context.new
      @socket  = @context.socket(ZMQ::REP)
      @socket.bind("tcp://*:#{DETECTOR_CONTROLLER_ZMQ_PORT_NUMBER}")
      @logger.info "Controller started"

      # Add controller modules
      add_controller_module(ControllerModuleDetector.new("det"))
      add_controller_module(ControllerModuleHV.new("hv"))
      add_controller_module(ControllerModuleDisplay.new("disp", @context))
      add_controller_module(ControllerModuleHK.new("hk"))

      # Send a log message to M2X
      send_log_to_m2x(LOG_MESSAGE_CONTROLLER_STARTED)
    end

    private
    def check_constants()
      {GROWTH_CONFIG_FILE: GROWTH_CONFIG_FILE,
       GROWTH_KEY_FILE: GROWTH_KEY_FILE,
       GROWTH_REPOSITORY: GROWTH_REPOSITORY
      }.each(){|label,file|
        if(file==nil or file=="")then
          @logger.fatal("#{label} environment variable not set")
          exit(-1)
        end
        if(!File.exists?(file))then
          @logger.fatal("#{label} #{file} not found")
          exit(-1)
        end
      }
    end

    # Load YAML configuration file, and set detectorID
    def load_growth_config_file()
      # Check file presence
      if(!File.exist?(GROWTH_CONFIG_FILE))then
        @logger.error "#{GROWTH_CONFIG_FILE} not found"
        exit(-1)
      end

      # Load YAML configuration file
      @logger.info "Loading #{GROWTH_CONFIG_FILE}"
      yaml = YAML.load_file(GROWTH_CONFIG_FILE)
      if(yaml["detectorID"]==nil or yaml["detectorID"]=="")then
        @logger.error "detectorID not found in #{GROWTH_CONFIG_FILE}"
        exit(-1)
      end

      # Get file output dir (event file and hk file will be saved in this directory)
      @output_dir = yaml["storage_path"]
      if(@output_dir==nil or @output_dir=="")then
        @logger.error "'storage_path' should appear in #{GROWTH_CONFIG_FILE}."
        exit(-1)
      end
      if(!File.exist?(@output_dir))then
        @logger.error "'storage_path' (#{@output_dir}) does not exist."
        exit(-1)
      end
      # Set instance variable and dump the result
      @detector_id = yaml["detectorID"]
      @logger.info "detectorID: #{@detector_id}"

    end

    # Load M2X keys
    def load_keys()
      @device_id = nil
      @primary_endpoint = nil
      @primary_api_key = nil
      # Get M2X keys
      if(GROWTH_KEY_FILE=="" or !File.exist?(GROWTH_KEY_FILE))then
        @logger.warn "M2X key file not found. Check if GROWTH_KEY_FILE environment variable is set."
        @logger.warn "M2X telemetry recording will be stopped."
        @use_m2x = false
        return
      end
      # Load the file
      @key_json = JSON.load(GROWTH_KEY_FILE)
      if(@key_json[@detector_id]==nil)then
        @use_m2x = false
        return
      end

      @device_id = @key_json[@detector_id]["m2x"]["device-id"]
      @primary_endpoint = "/devices/#{@device_id}"
      @primary_api_key = @key_json[@detector_id]["m2x"]["primary-api-key"]
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
      if(@controller_modules[subsystem]!=nil)then
        controller_module = @controller_modules[subsystem]
        if(controller_module.has_command(command))then
          reply = controller_module.send(command, option)
          if (reply==nil or !reply.instance_of?(Hash)) then
			@logger.warn("Subsystem '#{subsystem}' returned invalid return value (not Hash)")
			@logger.warn("Returned value = #{reply}")
			reply = {}
          end
          reply["subsystem"] = subsystem
          return reply.to_json
        end
      else
        subsystem_not_found_message = {sender: "detector_controller", status: "error", message: "Subsystem '#{subsystem}' not found"}.to_json
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
    public
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
      if(!@use_m2x)then
        return
      end

      stream_id = "detector-status"
      url = "http://api-m2x.att.com/v2/devices/#{@device_id}/streams/#{stream_id}/value"
      json = { value: str }.to_json
      @logger.info "URL = #{url}"
      @logger.info "json = #{json}"
      @logger.info `curl -i -X PUT #{url} -H "X-M2X-KEY: #{@primary_api_key}" -H "Content-Type: application/json" -d "#{json.gsub('"','\"')}"`
    end

    # Add ControllerModule instance
    def add_controller_module(controller_module)
      controller_module.controller = self
      @controller_modules[controller_module.name] = controller_module
      @logger.info "ControllerModule #{controller_module.name} added"
    end

    # Getter/setter
    attr_accessor :detector_id
  end
end
