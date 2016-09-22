require "rbczmq"
require "json"
require "yaml"
require "socket"

module GROWTH

class ControllerModuleDisplay < ControllerModule
	# TCP port number of display server
	DisplayServerPortNumber = 10010

	def initialize(name, zmq_context)
		super(name)
		define_command("clear")
		define_command("display")
		define_command("connected")

		@context = zmq_context
		
		@logger = Logger.new(STDOUT)
		@logger.progname = "ControllerModuleDisplay"

		connect()
	end

	private
	def connect()
		@logger.info("Connecting to display server...")
		@requester = @context.socket(ZMQ::REQ)
		begin
			@requester.connect("tcp://localhost:#{DisplayServerPortNumber}")
			@requester.rcvtimeo = 1000
			@requester.sndtimeo = 1000
			@logger.info("Connected to display server")
		rescue
			@logger.error("Connection failed. It seems Controller is not running")
			@requester = nil
		end
	end

	private
	def send_command(hash)
		# Connect if necessary
		if(@requester==nil)then
			connect()
		end
		if(@requester==nil)then
			@logger.warn("Continue with being disconnected from display server")
			return {status: "error", message: "Could not connect to display server"}
		end
		@requester.send(hash.to_json.to_s)
		return receive_reply()
	end

	private
	def receive_reply()
		begin
			reply_message = @requester.recv()
			@logger.debug(reply_message)
			return JSON.parse(reply_message)
		rescue => e
			@logger.warn("receive_reply() returning error (#{e})")
			return {status: "error", message: "ZeroMQ communication failed"}
		end		
	end

	#---------------------------------------------
	# Implemented commands
	#---------------------------------------------
	# Clears display
	def clear(option_json)
		@logger.debug("clear command invoked")
		return send_command({command: "clear"})
	end

	# Displays string
	# option_json should contain "message" entry.
	def display(option_json)
		@logger.debug("display command invoked")
		return send_command({command: "display", option:option_json})
	end

	# Returns the status of connection to the
	# display server.
	def connected(option_json)
		if(@requester==nil)then
			connect()
		end
		if(@requester!=nil)then
			return {status: "ok", message: "true"}
		else
			return {status: "ok", message: "false"}
		end
	end

	# Ping the server
	def ping(option_json)
		return send_command({command: "ping"})
	end
end

end
