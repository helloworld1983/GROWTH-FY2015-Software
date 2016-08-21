#!/usr/bin/env ruby
require "rbczmq"
require "json"
require "pry"
PortNumber = 5555

#---------------------------------------------
# ConsoleModules
#---------------------------------------------
class ConsoleModule
	def initialize(requester, name)
		@requester = requester
		@name = name
	end

	def sendCommand(command, optionHash={})
		jsonCommand = {command: name+"."+command, option: optionHash}.to_json
		puts "Sending command: #{jsonCommand}"
		$requester.send(jsonCommand.to_s)
		return receiveReply()
	end

	def receiveReply()
		begin
			replyMessage = $requester.recv()
			return JSON.parse(replyMessage)
		rescue
			return {}.to_json
		end
		
	end

	attr_accessor :requester, :name
end

class ConsoleModuleDetector < ConsoleModule
	def initialize(requester, name)
		super(requester, name)
	end

	def id()
		return sendCommand("id")
	end

	def ip()
		return sendCommand("ip")
	end

	def hash()
		return sendCommand("hash")
	end

	def ping()
		return sendCommand("ping")
	end
end

class ConsoleModuleHV < ConsoleModule
	def initialize(requester, name)
		super(requester, name)
	end

	def on(ch)
		return sendCommand("on", {ch: ch})
	end

	def off(ch)
		return sendCommand("off", {ch: ch})
	end

	def off_all()
		return sendCommand("off_all")
	end
end

#---------------------------------------------
# Open ZeroMQ client connection
#---------------------------------------------
context = ZMQ::Context.new
puts "Connecting to Controller..."
$requester = context.socket(ZMQ::REQ)
begin
	$requester.connect("tcp://localhost:#{PortNumber}")
	# if(status<0)then
	# 	puts ZMQ::Util::error_string
	# 	exit -1
	# end
rescue
	puts "Error: connection failed. It seems Controller is not running"
	exit -1
end
puts "Connected"

#---------------------------------------------
# Instantiate ConsoleModules
#---------------------------------------------
det = ConsoleModuleDetector.new($requester, "det")
hv  = ConsoleModuleHV.new($requester, "hv")

#---------------------------------------------
# Start console
#---------------------------------------------
binding.pry

$requester.close
