#!/usr/bin/env ruby

require "pry"
require "growth_controller/console_modules"

class DisplayUpdater
  def initialize()
    @logger = Logger.new(STDOUT)
    @logger.progname = "growth_display_updater"

    @logger.info("Initializing the display updater...")

    @growth_config = GROWTH::Config.new()
    if(!@growth_config.has_hv_conversion())then
    	@logger.fatal("growth_config should contain HV conversion equation. See the user manual.")
    	exit(-1)
    end

    @det  = GROWTH::ConsoleModuleDetector.new("det")
    @hv   = GROWTH::ConsoleModuleHV.new("hv")
    @disp = GROWTH::ConsoleModuleDisplay.new("disp")
    @hk   = GROWTH::ConsoleModuleHK.new("hk")
    @daq  = GROWTH::ConsoleModuleDAQ.new("daq")

    # Variables used to calculate count rate
    @daq_count_previous = 0
    @daq_time_previous = 0
  end

  def update(lines)
    @disp.display lines
  end

  def construct_message()

    # Generates debug message for OLED display on the daughter board
    # Example: 31 x 6 characters
    #
    #          012345678901234567890
    #        + ----------------------+
    # Line 0 | FY2016A 0604 04:47:38 | [DetID] [Date/time]
    # Line 1 | DAQ Running 150 Hz    | [Status] [Cnt Rate]
    # Line 2 | 5/3/12 580 140 300 mA | [Volt] [Current]
    # Line 3 | 28.7deg 1008hPa 63.1% | [Temp] [Pressure] [Humidity]
    # Line 4 | WiFi:192.168.0.104    | [LAN/WiFi] [IP Address]
    # Line 5 | HV: 1000 ON / 1000 ON | [HV Volt/Status]
    #        + ----------------------+

    #---------------------------------------------
    # Line 0
    #---------------------------------------------
    # Detector ID
    detector_id = growth_config.detector_id()
    detector_id_latter = detector_id.split("-")[1].upcase().strip()

    # Date/time
    datetime = Time.now()
    mmdd = "%02d%02d" % [datetime.month, datetime.day]
    hhmmss = "%02d:%02d:%02d" % [datetime.hour, datetime.min, datetime.sec]

    #---------------------------------------------
    # Line 1
    #---------------------------------------------
    # Observation status
    daq_str = ""
    begin
    	daq_status = @daq.status
    	count_rate = 0
    	if @daq_count_previous!=0 and @daq_time_previous!=0 then
    		daq_count_current = daq_status["nEvents"]
    		daq_time_current = daq_status["unixTime"]
    		if(daq_time_current!=@daq_time_previous)then
    			delta_time = daq_time_current - @daq_time_previous
	    		count_rate = (daq_count_current-@daq_count_previous)/delta_time
	    	end
    	end
    	daq_str = "DAQ %7s %3dHz" % [daq_status["daqStatus"], count_rate]
    rescue => e
    	daq_str = "DAQ comm error"
    end

    #---------------------------------------------
    # Line 2/3
    #---------------------------------------------
    current_str = ""
    bme280_str = ""
    hk = nil
    
    # Current
    begin
    	hk = @hk.read()
    	# 12V current
    	current_12v = hk["hk"]["slow_adc"]["2"]["converted_value"]
    	# 5V current
    	current_5v = hk["hk"]["slow_adc"]["3"]["converted_value"]
    	# 3.3V current
    	current_3v3 = hk["hk"]["slow_adc"]["4"]["converted_value"]
    	# Construct string
    	current_str = "%3d %3d %3d" % [current_12v, current_5v, current_3v3]
    rescue => e
    	current_str = "SLOWADC ERROR"
    end

    # Temperature/humidity/pressure
    begin
    	bme280_str = "%4.1fdeg %4dhPa %4.1f%%" % [
	    	hk["hk"]["bme280"]["temperature"],
	    	hk["hk"]["bme280"]["humidity"],
	    	hk["hk"]["bme280"]["humidity"]
		]
    rescue => e
    	bme280_str = "BME280 ERROR"
    end

    # Line 2 | 5/3/12 580 140 300 mA | [Volt] [Current]
    # Line 3 | 28.7deg 1008hPa 63.1% | [Temp] [Pressure] [Humidity]

    #---------------------------------------------
    # Line 4
    #---------------------------------------------
    ip = ""
    begin
    	ip=@det.ip()["ip"]
    rescue => e
    	ip="ERROR"
    end

    #---------------------------------------------
    # Line 5
    #---------------------------------------------
    hv_status_str = ""
    begin
	    hv_status = @hv.status()
    	hv_status_str = "%4d %3s %4d %3s" % [
    		@growth_config.to_hv_voltage(hv_status["0"]["value_in_mV"]),
    		hv_status["0"]["status"].upcase,
    		@growth_config.to_hv_voltage(hv_status["0"]["value_in_mV"]),
			hv_status["1"]["status"].upcase
    	]
    rescue => e
    	hv_status_str = "ERROR"
    end

    #---------------------------------------------
    # Construct whole message
    #---------------------------------------------
    str = <<EOS
    #{detector_id_latter} #{mmdd} #{hhmmss}
    Obs: Running 105 Hz
    5/3/12 #{current_str}
    #{bme280_str}
    IP #{ip}
    HV #{hv_status_str}
    EOS
  end
end
