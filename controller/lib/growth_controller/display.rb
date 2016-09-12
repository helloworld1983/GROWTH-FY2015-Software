require "rbczmq"
require "json"
require "yaml"
require "socket"

class ControllerModuleDisplay < ControllerModule
	# TCP port number of display server
	DisplayServerPortNumber = 10010

	def initialize(name)
		super(name)
		define_command("clear")
		define_command("display")
		define_command("connected")

		@logger = Logger.new(STDOUT)
		@logger.progname = "ControllerModuleDisplay"

		connect()
	end

	private
	def connect()
		@logger.info("Connecting to display server...")
		@context = ZMQ::Context.new
		@requester = context.socket(ZMQ::REQ)
		@requester.recv_timeout = 1
		@requester.send_timeout = 1
		begin
			$requester.connect("tcp://localhost:#{DisplayServerPortNumber}")
			@logger.info("Connected to display server")
		rescue
			@logger.error("Connection failed. It seems Controller is not running")
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
			return {status: "error", message: "Could not connect to display server"}.to_json
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
		if(@requester==Nil)then
			connect()
		end
		if(@requester!=Nil)then
			return {status: "ok", message: "true"}.to_json
		else
			return {status: "ok", message: "false"}.to_json
		end
	end

	# Ping the server
	def ping(option_json)
		return send_command({command: "ping"})
	end
end