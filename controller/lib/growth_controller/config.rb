require "yaml"
require "logger"

module GROWTH
	# Set config file path
	if(ENV["GROWTH_CONFIG_FILE"]!=nil and File.exists?(ENV["GROWTH_CONFIG_FILE"]))then
		@@growth_config_file = File.expand_path(ENV["GROWTH_CONFIG_FILE"])
	if(File.exists?("~/growth_config.yaml"))then
		@@growth_config_file = File.expand_path("~/growth_config.yaml")
	elsif(File.exists?("/etc/growth/growth_config.yaml"))then
		@@growth_config_file = File.expand_path("/etc/growth/growth_config.yaml")
	end

class Config
	def initialize()
		@logger = Logger.new(STDOUT)
		@logger.progname = "GROWTH::Config"

		load_config_file()
	end
	attr_accessor :detector_id
	attr_accessor :has_hv_conversion

	def growth_config_file_path()
		return @@growth_config_file
	end

	def to_hv_voltage(ch, dac_voltage_mV)
		if @has_hv_conversion then
			x = dac_voltage_mV
			if(@hv_conversion[ch]==nil)then
				@logger.error("growth_config does not define HV conversion equations for channel #{ch}.")
				return -999
			else
				return eval(@hv_conversion[ch])
			end
		else
			@logger.error("growth_config does not define conversion equations for HV DAC.")
			return 0
		end
	end

	private
  def load_config_file()
    # Check file presence
    if(!File.exist?(GROWTH_CONFIG_FILE))then
      @logger.error "#{GROWTH_CONFIG_FILE} not found"
      exit(-1)
    end

    # Load YAML configuration file
    @logger.info "Loading #{GROWTH_CONFIG_FILE}"
    yaml = YAML.load_file(GROWTH_CONFIG_FILE)

    # Detector ID
    if(yaml["detectorID"]==nil or yaml["detectorID"]=="")then
      @logger.error "detectorID not found in #{GROWTH_CONFIG_FILE}"
      exit(-1)
   	else
   		@detector_id = yaml["detectorID"]
   		@logger.info "detectorID: #{@detector_id}"
    end

    # HV conversion equation
    if(yaml["hv"]==nil)then
    	@has_hv_conversion = true
    	@hv_conversion = {}
    	for ch,equation in yaml["hv"]
    		# equation should be like "x/3300 * 1000"
    		hv_conversion[ch] = equation
    		@logger.info("HV Ch.#{ch} HV_V = #{equation.gsub("x","DAC_mV")}")
    	end
    else
    	@logger.warn("No HV conversion equation defined")
    	@has_hv_conversion = false
    end

  end

end

end