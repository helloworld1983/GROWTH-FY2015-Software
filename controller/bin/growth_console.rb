#!/usr/bin/env ruby
require "rbczmq"
require "json"
require "pry"
require "logger"

require "growth_controller/detector_controller"

#---------------------------------------------
# ConsoleModules
#---------------------------------------------
class ConsoleModule
	def initialize(requester, name)
		@logger = Logger.new(STDOUT)
		@logger.progname = "ConsoleModule"
		@requester = requester
		@name = name
	end

	def send_command(command, option_hash={})
		json_command = {command: name+"."+command, option: option_hash}.to_json
		@logger.info("Sending command: #{json_command}")
		$requester.send(json_command.to_s)
		return receive_reply()
	end

	def receive_reply()
		begin
			reply_message = $requester.recv()
			return JSON.parse(reply_message)
		rescue
			return {}.to_json
		end
	end

	attr_accessor :requester, :name
end

class ConsoleModuleDetector < ConsoleModule
	def initialize(requester, name)
		super(requester, name)
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
	def initialize(requester, name)
		super(requester, name)
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
	def initialize(requester, name)
		super(requester, name)
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
	def initialize(requester, name)
		super(requester, name)
		@logger.progname = "ConsoleModuleHK"
	end

	# Clears the display output
	def read()
		return send_command("read")
	end
end

logger = Logger.new(STDOUT)
logger.progname = "growth_console"

#---------------------------------------------
# Open ZeroMQ client connection
#---------------------------------------------
context = ZMQ::Context.new
logger.info("Connecting to Controller...")
$requester = context.socket(ZMQ::REQ)
begin
	$requester.connect("tcp://localhost:#{GROWTH::DetectorController::DETECTOR_CONTROLLER_ZMQ_PORT_NUMBER}")
rescue
	logger.fatal("connection failed. It seems Controller is not running")
	exit -1
end
@logger.info("Connected")

#---------------------------------------------
# Instantiate ConsoleModules
#---------------------------------------------
det  = ConsoleModuleDetector.new($requester, "det")
hv   = ConsoleModuleHV.new($requester, "hv")
disp = ConsoleModuleDisplay.new($requester, "disp")

#---------------------------------------------
# Start console
#---------------------------------------------
binding.pry

$requester.close
