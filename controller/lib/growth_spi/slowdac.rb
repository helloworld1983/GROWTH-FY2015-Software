#!/usr/bin/env ruby

require "json"
require "pi_piper"
require "logger"

module growth_spi

  # Sets Slow DAC output values.
  class SlowDAC

    # Gain setting: 0=gain 2x, 1=gain 1x
    NGAIN = 0

    # Shutdown setting: 0=shutdown 1=output enabled
    NSHDN = 1

    # Logger instance used by this class
    self.logger = Logger.new(STDOUT)

    # Sets output value in mV. DAC will output specified voltage soon
    # after this method is invoked. When one or more of specified
    # parameters are invalid, an error message will be output to
    # STDOUT via logger.
    #
    # @param ch output channel (0 or 1)
    # @param voltage_in_mV output voltage in mV (0-3300 mV)
    def self.set_output(ch, voltage_in_mV)
      # Check parameters
      if(ch<0 or ch>1)then
        self.logger.error("SlowDAC Output channel should 0 or 1 (#{ch} provided)")
        return
      end

      if(voltage_in_mV<0 or voltage_in_mV>3300)then
        self.logger.error("SlowDAC Output voltage should be >=0 and <=3300 (#{voltage_in_mV} provided)")
        return
      end

      # Construct SPI instance
      begin
        PiPiper::Spi.begin(PiPiper::Spi::CHIP_SELECT_0) do |spi|
          header = "0b#{ch}0#{NGAIN}#{NSHDN}".to_i(2) << 12
          register_value = header + voltage_in_mV
          self.logger.info("SlowDAC sets Ch. #{ch} voltage at #{"%.3f"%(value/1000.0)} V")
          spi.write [ register_value/0x100, register_value%0x100 ]
        end
      rescue

      end
    end
  end

end