
#
# Generates debug message for OLED display on the daughter board
# Example: 31 x 6 characters
# 
#          012345678901234567890
#        + ----------------------+
# Line 0 | FY2016A 0604 04:47:38 | [DetID] [Date/time]
# Line 1 | Obs 0:105 Hz 1:105 Hz | [Status] [Cnt Rate]
# Line 2 | 5/3/12 580 140 300 mA | [Volt] [Current]
# Line 3 | 28.7deg 1008hPa 63.1% | [Temp] [Pressure] [Humidity]
# Line 4 | WiFi:192.168.0.104    | [LAN/WiFi] [IP Address]
# Line 5 | HV: 1000 ON / 1000 ON | [HV Volt/Status]
#        + ----------------------+

#---------------------------------------------
# Line 0
#---------------------------------------------
# Detector ID
detectorID="growth-fy2015b"
detectorIDLatter = detectorID.split("-")[1].upcase().strip()

# Date/time
datetime = Time.now()
mmdd = "%02d%02d" % [datetime.month, datetime.day]
hhmmss = "%02d:%02d:%02d" % [datetime.hour, datetime.min, datetime.sec]

# Observation status


str = <<EOS
#{detectorIDLatter} #{mmdd} #{hhmmss}
Obs: Running 105 Hz
5/3/12 580 140 300 mA 
28.7deg 1008hPa 63.1%
WiFi:192.168.0.104
HV: 1000 ON / 1000 ON
EOS

print str