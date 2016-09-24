#!/usr/bin/env ruby

require "growth_controller/console_modules"

# This script starts/pauses/resumes DAQ program (i.e. observation of gamma-ray
# events) by watching several conditions such as the electronics temperature. 

# Reads HK and check if a DAQ run can be started.
# Check result can be accessed via daq_run_can_be_started() method.

class HKChecker

  HK_CHECK_PERIOD_SEC = 60

  def initialize(logger, growth_config)
    @logger = logger
    @growth_config = growth_config

    # Check if temperature limits are defined in growth_config.yaml
    if(!@growth_config.has_temperature_limit)then
      @logger.fatal("Temperature limits should be defined in growth_config.yaml")
      exit(-1)
    end

    @stopped = false

    @hk = GROWTH::ConsoleModuleHK.new("hk")
    @daq_run_can_be_started = false
  end

  attr_accessor :daq_run_can_be_started
  attr_accessor :stopped

  def run()
    while(!@stopped)
      @logger.debug("Check if DAQ automatic run can be started...")
      # Read HK from HK module
      hk_data = @hk.read()
      
      # Check if conditions are met.
      if(hk_data["status"]=="ok")then
        
        # Slide switch determines if automatic run should be started
        automatic_run_enabled = (hk_data["hk"]["slide_switch_status"]=="on")
        @logger.debug("Slide switch = #{hk_data["hk"]["slide_switch_status"]}")

        # Temperature is inside the limits
        temperature_valid = false
        if(hk_data["hk"]["slowadc"][0]!=nil)then
          fpga_board_temp0 = hk_data["hk"]["slowadc"][0]["converted_value"]
          fpga_board_temp1 = hk_data["hk"]["slowadc"][1]["converted_value"]
          fpga_board_temp0_valid = @growth_config.inside_temperature_limit(fpga_board_temp0)
          fpga_board_temp1_valid = @growth_config.inside_temperature_limit(fpga_board_temp1)
          temperature_valid = (fpga_board_temp0_valid and fpga_board_temp1_valid)
          @logger.debug("FPGA Board Temperature #{fpga_board_temp0} degC and #{fpga_board_temp1} degC")
        end

        # TODO: add current limit check

        # Compose a resulting value
        if(automatic_run_enabled and temperature_valid)then
          @daq_run_can_be_started = true
        else
          @daq_run_can_be_started = false
        end

      else
        # When HK is not available due to e.g. SPI communication error,
        # automatic run cannot be started.
        @daq_run_can_be_started = false
      end

      @logger.debug("Automatic DAQ start = #{@daq_run_can_be_started}")
      sleep(HK_CHECK_PERIOD_SEC)
    end
  end
end

class DAQRunManager

  WAIT_DURATION_SEC = 15

  def initialize(logger, growth_config)
    @logger = logger
    @growth_config = growth_config
    @hv   = GROWTH::ConsoleModuleHV.new("hv")  
    @daq  = GROWTH::ConsoleModuleDAQ.new("daq")
    
    @hk_check_thread = Thread.new() do
      @hk_checker = HKChecker.new(logger, growth_config)
      @hk_checker.run()
    end
  end

  attr_accessor :stopped

  def run()
    while(true)
      @logger.debug("Autorun check...")
      daq_status = @daq.status()
      if(daq_status["status"]=="ok")then
        # If currently paused, check the auto-run status.
        if(daq_status["daqStatus"]=="Paused")then
          @logger.debug("DAQ program is paused.")
          # If auto run conditions are met, start a new run. 
          if(@hk_checker.daq_run_can_be_started)then
            @logger.info("Automatic run can be started (conditions are met)")
            @logger.info("Turning on HV")
            for ch in [0,1]
              dac_mV = get_detault_hv_DAC_mV(ch)
              if(dac_mV!=0 and dac_mV>0)then
                @hv.on(ch, dac_mV)
              end
            end
            @logger.info("Resuming DAQ run")
            @daq.resume()
          else
            # Nothing to do (wait until conditions are met)
            @logger.debug("Autorun conditions are not met.")
          end
        else
          # If DAQ is running, check if the run can be continued.
          if(@hk_checker.daq_run_can_be_started)then
            @logger.debug("DAQ program is running.")
            # Check elapsed time, and switch output file if exposure exceeds the limit.
            elapsed_sec = daq_status["elapsedTimeOfCurrentOutputFile"]
            @logger.debug("Current file = daq_status["outputFileName"] Elapsed time = #{elapsed_sec}")
            if(elapsed_sec>=@growth_config.autorun_daq_exposure_sec or elapsed_sec<0)then
              @logger.info("Switching output file (closing #{daq_status["outputFileName"]})")
              @daq.switch_output()
            end
          else
            # The DAQ run should be paused, and HV should be turned off.
            @logger.warn("Limit check not satisfied. The current DAQ run is terminated, and DAQ program is paused.")
            @daq.pause()
            @hv.off_all()
          end
        end
      else
        @logger.warn("DAQ program is not running. Wait until it is restarted by God.")
      end
      # Wait a while before the next check
      sleep(WAIT_DURATION_SEC)
    end
    @hk_checker.stopped = true
    @hk_check_thread.join()
  end

end

@logger = Logger.new(STDOUT)
@logger.progname = "growth_daq_run_manager"

@logger.info("Starting...")
@growth_config = GROWTH::Config.new()

daq_run_manager = DAQRunManager.new(@logger, @growth_config)
daq_run_manager.run()