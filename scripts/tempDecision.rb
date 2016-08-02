#!/usr/bin/ruby

temp=ARGV[0].to_f
processID=ARGV[1]

tempRestart=35.0
tempStop=45.0
tempUpper=60.0
tempLower=-20.0

if(temp <= tempRestart)&&(temp > tempLower)&&(processID == nil) then
  puts "start"
elsif
  (temp >= tempStop)&&(temp < tempUpper)&&(processID != nil) then
  puts "stop"
else
  puts "stay"
end
