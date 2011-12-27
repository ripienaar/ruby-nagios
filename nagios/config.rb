module Nagios
=begin rdoc

Configuration parser for Nagios. Constructor parses Nagios' main
config file and returns an object: each configuration option's value
assigned to an instance variable and attribute reader method is
created.

Can be used as:

      require 'nagios/config'
      nagios = Nagios::Config.new "lib/ruby-nagios/test/data/nagios.cfg"
      nagios.log_file
  => "/var/log/nagios3/nagios.log"


=end  
  class Config
    # Read and parse configuration file.
    #
    # @param [String] config_file PATH to the configuration file. If
    #     PATH is not provided method will look for configuration file
    #     +nagios.cfg+ in +/etc/nagios*+ directory.
    # @note If you have more than one /etc/nagios* directories then
    #    only first one will be used. For example, Debian can have
    #    both Nagios 2 and 3 installed. In the latter case
    #    configuration file is +/etc/nagios3/nagios.cfg+.
    # @author Dmytro Kovalov, dmytro.kovalov@gmail.com
    def initialize config_file=nil
      @config = config_file || Dir.glob("/etc/nagios*/nagios.cfg").first
      raise "Configuration file #{@config} does not exist" unless File.exist? @config
      raise "Configuration file #{@config} is not readable" unless File.readable? @config

      File.readlines(@config).map{ |l| l.sub(/#.*$/,'')}.delete_if { |l| l=~ /^$/}.each do |l|
        key,val = l.strip.split('=',2)
        raise "Incorrect configuration line #{l}" unless key && val

        case key
        when /cfg_(file|dir)/
          instance_variable_set("@#{key}", (instance_variable_get("@#{key}") || []) << val )
        else
          instance_variable_set("@#{key}", val)
          instance_eval val =~ /^[\d\.-]+/ ? 
          "def #{key}; return #{val}; end" :
            "def #{key}; return %Q{#{val}}; end"
        end
      end
    end

    # Special case for cfg_file and cfg_dir: they are Arrays
    attr_reader :cfg_file, :cfg_dir

  end
end
