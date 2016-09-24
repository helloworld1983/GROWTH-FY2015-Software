require "rbczmq"
require "json"
require "logger"

DETECTOR_CONTROLLER_ZMQ_PORT_NUMBER   = 10000

module GROWTH

#---------------------------------------------
# ConsoleModules
#---------------------------------------------
class ConsoleModule
	
	@@context = ZMQ::Context.new

	def initialize(name)
		@logger = Logger.new(STDOUT)
		@logger.progname = "ConsoleModule"
		@requester = nil
		@name = name
	end

	def connect()
		# Open ZeroMQ client connection
		@logger.info("Connecting to Controller...")
		@requester = @@context.socket(ZMQ::REQ)
		begin
			@requester.connect("tcp://localhost:#{DETECTOR_CONTROLLER_ZMQ_PORT_NUMBER}")
			@requester.rcvtimeo = 1000
			@requester.sndtimeo = 1000
		rescue
			@logger.fatal("connection failed. It seems Controller is not running")
			raise "Connection failed"
		end
		@logger.info("Connected to Controller")
	end

	def send_command(command, option_hash={})
		json_command = {command: name+"."+command, option: option_hash}.to_json
		@logger.info("Sending command: #{json_command}")
		begin
			if(@requester==nil)then
				connect()
			end
			@requester.send(json_command.to_s)
		rescue => e
			@logger.error("ZerMQ send failed (#{e})")
			@requester.close
			@requester = nil
			return {status: "error", message: "ZeroMQ send failed (#{e})"}
		end
		return receive_reply()
	end

	def receive_reply()
		begin
			if(@requester==nil)then
				connect()
			end
			reply_message = @requester.recv()
			return JSON.parse(reply_message)
		rescue => e
			@logger.error("ZerMQ receive failed (#{e})")
			@requester.close
			@requester = nil
			return {status: "error", message: "ZeroMQ receive failed (#{e})"}
		end
	end

	attr_accessor :name
end

class ConsoleModuleDetector < ConsoleModule
	def initialize(name)
		super(name)
		@logger.progname = "ConsoleModuleDetector"
	end

	def id()
		return send_command("id")
	end

	def ip()
		return send_command("ip")
	end

	def hash()
		return send_command("hash")
	end

	def ping()
		return send_command("ping")
	end
end

class ConsoleModuleHV < ConsoleModule
	def initialize(name)
		super(name)
		@logger.progname = "ConsoleModuleHV"
	end

	def on(ch, value_in_mV)
		return send_command("on", {ch: ch, value_in_mV:value_in_mV})
	end

	def off(ch)
		return send_command("off", {ch: ch})
	end

	def off_all()
		return send_command("off_all")
	end
end

class ConsoleModuleDisplay < ConsoleModule
	def initialize(name)
		super(name)
		@logger.progname = "ConsoleModuleDisplay"
	end

	# Clears the display output
	def clear()
		return send_command("clear")
	end

	# Displays message on the screen
	def display(str)
		return send_command("display", {message: str})
	end

	# Stops display server (for test)
	def stop()
		return send_command("stop")
	end
end

class ConsoleModuleHK < ConsoleModule
	def initialize(name)
		super(name)
		@logger.progname = "ConsoleModuleHK"
	end

	# Clears the display output
	def read()
		return send_command("read")
	end
end

class ConsoleModuleDAQ < ConsoleModule
	def initialize(name)
		super(name)
		@logger.progname = "ConsoleModuleHK"
	end

	def ping()
		return send_command("ping")
	end

	def stop()
		return send_command("stop")
	end

	def pause()
		return send_command("pause")
	end

	def resume()
		return send_command("resume")
	end

	def status()
		return send_command("status")
	end

	def switch_output()
		return send_command("switch_output")
	end
end

end