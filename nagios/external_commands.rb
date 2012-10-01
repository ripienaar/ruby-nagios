module Nagios
  #check_external_commands=1
  #command_file=/var/lib/nagios3/rw/nagios.cmd

  # Class Nagios::ExternalCommands is class implementing sending
  # commands to external commands file in Nagios.
  #
  # From nagios.cfg file:
  #
  # This is the file that Nagios checks for external command requests.
  # It is also where the command CGI will write commands that are
  # submitted by users, so it must be writeable by the user that the
  # web server is running as (usually 'nobody').
  #
  # == Usage
  #
  #     command = Nagios::ExternalCommands.new Nagios::Config.new.parse.command_file
  #
  #     command.send :action => :PROCESS_HOST_CHECK_RESULT, :host_name => 'myhost', :status_code => 0, :plugin_output => "PING command OK"
  #
  class ExternalCommands

    require 'erb'

    # List of all available nagios external commands, formats and
    # descripttions can be obtained from
    # http://www.nagios.org/developerinfo/externalcommands As of the
    # time of writing this list is 157 commands for Nagios 3.x.
    #
    # Format for the actions Hash: it's ERB template with Nagios
    # variables. Each variable must be defined as attr_accessor, these
    # variables are used in ERB binding.
    #
    # Format string of data sent by this is the same as used in Nagios
    # external commands description, where semicolon-separated values
    # are replaced by <%= ... %> ERB varaibles. 
    ACTIONS = { 
      PROCESS_SERVICE_CHECK_RESULT: ";<%= host_name %>;<%= service_description %>;<%= return_code %>;<%= plugin_output %>",
      PROCESS_HOST_CHECK_RESULT:    ";<%= host_name %>;<%= status_code %>;<%= plugin_output %>"
    }


    # Constructor for teh external commnd send class.
    #
    # @param [String] path Full UNIX path to external command file
    #
    # == Example
    #     >> cmd = Nagios::ExternalCommands.new('/tmp/test', {:host_name => 'host', :action => :PROCESS_HOST_CHECK_RESULT})
    #       => #<Nagios::ExternalCommands:0x007f8775138f18 @path="/tmp/test", @host_name="host", @action=:PROCESS_HOST_CHECK_RESULT>
    def initialize path
      raise ArgumentError, "External command file name must be provided" unless path

      raise RuntimeError,  "External command directory holding file #{path} is not writable by this user." unless Dir.writable? File.dirname path

      # In Nagios3 command file is purged and re-created each time commnds are processed/added.

      #      raise RuntimeError,  "External command #{path} does not exist or not accessible" unless File.exist? path
      #      raise RuntimeError,  "External command #{path} is not writable" unless File.writable? path
      @path = path
      
    end

    attr_reader :path
    
    # Action to send: one of the keys listed in
    # ::Nagios::ExternalCommands::ACTIONS hash.
    attr_accessor :action
    
    # Timestamp - usually time when send is performaed, but can be
    # overridden by params[:ts] in constructor. If given as argument
    # for constructor it should be String of the format:
    # Time.to_i.to_s (i.e number of seconds since epoch).
    attr_accessor :ts

    # Thes accessors requried for ERB Binding to work
    attr_accessor :host_name, :service_description, :return_code, :plugin_output, :status_code

    # Get private binding to use with ERB bindings.
    def get_binding
      binding()
    end

    # Send command to Nagios. Prints formatted string to external command file (pipe).
    #
     # @param [Hash] params Data to send to command file pipe. Must include :action and all additional varables
    def send params

      raise ArgumentError, "Action name must be provided" unless params.has_key? :action
      raise ArgumentError, "Action name #{params[:action]} is not implemented" unless ACTIONS.keys.include? params[:action]
      
      params.each do |k,v|
        self.instance_variable_set "@#{k}", v
      end

      self.ts = params[:ts] || Time.now.to_i.to_s

      format = "#{ts} " << self.action.to_s << ACTIONS[self.action]
      
      File.open(path, 'a') do |pipe|
        pipe.puts ERB.new(format).result(self.get_binding)
        pipe.close
      end
    end

  end
end

