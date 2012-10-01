module Nagios

=begin rdoc

Parser of the main Nagios configuration file -- nagios.cfg. 

Constructor parses Nagios' main config file and returns an object:
each configuration option's value assigned to an instance variable and
attribute reader method is created.

Can be used as:

      require 'nagios/config'
      nagios = Nagios::Config.new "lib/ruby-nagios/test/data/nagios.cfg"

      nagios.log_file
  => "/var/log/nagios3/nagios.log"

      nagios.status_file
  => "/var/cache/nagios3/status.dat"

= Configuration of the module

Default search directory and file pattern (Dir.glob) is defined by
Nagios::DEFAULT[:nagios_cfg_glob] constant. It is set in
+config/default.rb+ file. 

@note If you have more than one /etc/nagios* directories then only
first one will be used. For example, Debian can have both Nagios 2 and
3 installed. In the latter case configuration file is
+/etc/nagios3/nagios.cfg+.


=end  
  class Config

    ##
    # Initialize configuration file path. Check existence and
    # readability of the file, raise exception if not.
    # 
    # @param [String] config_file PATH to the configuration file. If
    #     PATH is not provided method will look for configuration file
    #     +nagios.cfg+ in directory, defined by
    #     Nagios::DEFAULT[:nagios_cfg_glob] constant ( ususally
    #     /etc/nagios*/nagios.cfg);
    #
    def initialize config_file=nil

      @config = config_file || Dir.glob( Nagios::DEFAULT[:nagios_cfg_glob] ).first
      @path = @config

      @configuration ||= {}
      raise "No configuration file option and no files in #{ DEFAULT[:nagios_cfg_glob] } " unless @config
      raise "Configuration file #{@config} does not exist" unless File.exist? @config
      raise "Configuration file #{@config} is not readable" unless File.readable? @config

    end

    # Hash holding all the configuration after parsing. Additionally
    # for every key in the configuration Hash method is created with
    # the same name, which returns the value.
    attr_accessor :configuration

    # Path to main configuration file nagios.cfg

    attr_accessor :path
    
    ##
    # Read and parse main Nagios  configuration file +nagios.cfg+
    #
    #
    # @author Dmytro Kovalov, dmytro.kovalov@gmail.com
    def parse

      File.readlines(@config).map{ |l| l.sub(/#.*$/,'')}.delete_if { |l| l=~ /^$/}.each do |l|
        key,val = l.strip.split('=',2)
        raise "Incorrect configuration line #{l}" unless key && val

        case key
          # There could be multiple entries for cfg_dir/file, so these
          # are Arrays.
        when /cfg_(file|dir)/
          @configuration[key] ||= []
          @configuration[key] << val
          instance_variable_set("@#{key}", (instance_variable_get("@#{key}") || []) << val )
        else

          @configuration[key] = val
          instance_variable_set("@#{key}", val)
          instance_eval val =~ /^[\d\.-]+/ ? 
          "def #{key}; return #{val}; end" :
            "def #{key}; return %Q{#{val}}; end"
        end
      end

      self
    end

    # Special case for cfg_file and cfg_dir: they are Arrays
    attr_reader :cfg_file, :cfg_dir

  end
end
