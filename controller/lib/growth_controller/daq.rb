require "rbczmq"
require "json"
require "yaml"
require "socket"

class ControllerModuleDAQ < ControllerModule
	# TCP port number of growth_daq ZeroMQ server
	DAQ_ZMQ_PORT_NUMBER = 10020

	def initialize(name, zmq_context)
		super(name)
		define_command("ping")
		define_command("stop")
		define_command("pause")
		define_command("resume")
		define_command("status")
		define_command("switch_output")

		@context = zmq_context

		@logger = Logger.new(STDOUT)
		@logger.progname = "ControllerModuleDAQ"

		connect()
	end

	private
	def connect()
		@logger.info("Connecting to DAQ ZeroMQ server...")
		@requester = @context.socket(ZMQ::REQ)
		@requester.recv_timeout = 1
		@requester.send_timeout = 1
		begin
			@requester.connect("tcp://localhost:#{DAQ_ZMQ_PORT_NUMBER}")
			@logger.info("Connected to DAQ ZeroMQ server")
		rescue
			@logger.error("Connection failed. It seems the DAQ program is not running")
			@requester = nil
		end
	end

	private
	def send_command(hash)
		# Connect if necessary
		if(@requester == nil)then
			connect()
		end
		if(@requester == nil)then
			return {status: "error", message: "Could not connect to DAQ ZeroMQ server"}
		end
		begin
			@requester.send(hash.to_json.to_s)
		rescue => e
			@requester.close
			@requester = nil
			@logger.warn("send_command() returning error (#{e})")
			return {status: "error", message: "ZeroMQ send failed (#{e})"}
		end
		return receive_reply()
	end

	private
	def receive_reply()
		begin
			reply_message = @requester.recv()
			return JSON.parse(reply_message)
		rescue
			@requester.close
			@requester = nil
			@logger.warn("receive_reply() returning error (#{e})")
			return {status: "error", message: "ZeroMQ communication failed (#{e}"}
		end		
	end

	#---------------------------------------------
	# Implemented commands
	#---------------------------------------------
	def ping(optionJSON)
		@logger.debug("ping command invoked")
		return sendCommand({command: "ping"})
	end

	def stop(optionJSON)
		@logger.debug("stop command invoked")
		return sendCommand({command: "stop"})
	end

	def pause(optionJSON)
		@logger.debug("pause command invoked")
		return sendCommand({command: "pause"})
	end

	def resume(optionJSON)
		@logger.debug("resume command invoked")
		return sendCommand({command: "resume"})
	end

	def status(optionJSON)
		@logger.debug("status command invoked")
		return sendCommand({command: "getStatus"})
	end

	def switch_output(optionJSON)
		@logger.debug("switch_output command invoked")
		return sendCommand({command: "startNewOutputFile"})
	end

end
