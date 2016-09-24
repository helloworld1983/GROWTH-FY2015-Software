#!/usr/bin/env ruby

require "pry"
require "growth_controller/console_modules"

@logger = Logger.new(STDOUT)
@logger.progname = "growth_display_updater"

disp = GROWTH::ConsoleModuleDisplay.new("disp")

while(i<10)
	lines = ["GROWTH-FY2016A", Time.now.to_s]
	disp.display(lines)
	sleep(2)
	i+=1
end