#!/usr/bin/env ruby

require "pry"
require "growth_controller/logger"
require "growth_controller/console_modules"

@logger = GROWTH.logger(ARGV, "growth_console")

#---------------------------------------------
# Instantiate ConsoleModules
#---------------------------------------------
det  = GROWTH::ConsoleModuleDetector.new("det")
hv   = GROWTH::ConsoleModuleHV.new("hv")
disp = GROWTH::ConsoleModuleDisplay.new("disp")
hk   = GROWTH::ConsoleModuleHK.new("hk")
daq  = GROWTH::ConsoleModuleDAQ.new("daq")

#---------------------------------------------
# Start console
#---------------------------------------------
binding.pry
