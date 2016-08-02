temp=ARGV[0].to_f
processID=ARGV[1]

if(temp <= 35.0)&&(processID == nil) then
  puts "start"
elsif
  (temp >= 45.0)&&(temp < 60.0)&&(processID != nil) then
  puts "stop"
else
  puts "stay"
end
