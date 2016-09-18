require "rbczmq"
require "json"
require "yaml"
require "socket"

class ControllerModuleDAQ < ControllerModule
	# TCP port number of display server
	DAQ_ZMQ_PORT_NUMBER = 10000

	def initialize(name)
		super(name)
		define_command("clear")
		define_command("display")
		define_command("connected")

		@logger = Logger.new(STDOUT)
		@logger.progname = "ControllerModuleDAQ"

		connect()
	end

	private
	def connect()
		@logger.info("Connecting to DAQ ZeroMQ server...")
		@context = ZMQ::Context.new
		@requester = context.socket(ZMQ::REQ)
		@requester.recv_timeout = 1
		@requester.send_timeout = 1
		begin
			$requester.connect("tcp://localhost:#{DAQ_ZMQ_PORT_NUMBER}")
			@logger.info("Connected to DAQ ZeroMQ server")
		rescue
			@logger.error("Connection failed. It seems the DAQ program is not running")
			@requester = Nil
		end
	end

	private
	def send_command(hash)
		# Connect if necessary
		if(@requester==Nil)then
			connect()
		end
		if(@requester==Nil)then
			return {status: "error", message: "Could not connect to DAQ ZeroMQ server"}.to_json
		end
		@requester.send(hash.to_json.to_s)
		return receive_reply()
	end

	private
	def receive_reply()
		begin
			reply_message = @requester.recv()
			return JSON.parse(reply_message)
		rescue
			return {status: "error", message: "ZeroMQ communication failed"}.to_json
		end		
	end

	#---------------------------------------------
	# Implemented commands
	#---------------------------------------------
	def clear(optionJSON)
		@logger.debug("clear command invoked")
		return sendCommand({command: "clear"})
	end
end