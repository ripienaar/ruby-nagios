module Nagios


  # Class Nagios::ExternalCommands is class implementing sending
  # commands to external commands file in Nagios.
  #
  # From nagios.cfg file:
  #
  # This is the file that Nagios checks for external command requests.
  # It is also where the command CGI will write commands that are
  # submitted by users, so it must be writable by the user that the
  # web server is running as (usually 'nobody').
  #
  # == Usage
  #
  #     command = Nagios::ExternalCommands.new Nagios::Config.new.parse.command_file
  #
  #     command.write :action => :PROCESS_HOST_CHECK_RESULT, 
  #       :host_name  => 'myhost', :status_code => 0, :plugin_output => "PING command OK"
  #
  class ExternalCommands

    require 'erb'
    require_relative 'external_commands/list'

    # Constructor for the external command write class.
    #
    # @param [String] path Full UNIX path to external command file
    #
    # == Example
    #
    #     >> cmd = Nagios::ExternalCommands.new('/tmp/test', 
    #         {:host_name => 'host', 
    #          :action => :PROCESS_HOST_CHECK_RESULT})
    #
    #       => #<Nagios::ExternalCommands:0x007f8775138f18 ...
    def initialize path
      raise ArgumentError, "External command file name must be provided" unless path
      raise RuntimeError,  "External command directory holding file #{path} is not writable by this user." unless File.writable? File.dirname path
      
      @path = path
    end

    attr_reader :path
    
    # Action to write: one of the keys listed in
    # ::Nagios::ExternalCommands::ACTIONS hash.
    attr_accessor :action
    
    # Time-stamp - usually time when write is performed, but can be
    # overridden by params[:ts] in constructor. If given as argument
    # for constructor it should be String of the format:
    # Time.to_i.to_s (i.e number of seconds since epoch).
    attr_accessor :ts

    # TODO: make int dynamically later with:
    # >> Nagios::ExternalCommands::ACTIONS.values.flatten.uniq
    # This returns full list of Nagios variables used in external commands
    #

    attr_accessor :host_name, :sticky, :notify, :persistent, :author,
    :comment, :service_description, :contact_name,
    :notification_timeperiod, :value, :varname, :varvalue,
    :event_handler_command, :check_command, :timeperiod,
    :check_attempts, :check_interval, :check_timeperiod,
    :notification_time, :comment_id, :downtime_id, :contactgroup_name,
    :hostgroup_name, :servicegroup_name, :file_name, :delete,
    :status_code, :plugin_output, :return_code, :start_time,
    :end_time, :fixed, :trigger_id, :duration, :check_time,
    :service_desription, :start_time, :options, :notification_number

    # Get private binding to use with ERB bindings.
    def get_binding
      binding()
    end

    # Send command to Nagios. Prints formatted string to external command file (pipe).
    #
    # @param [Hash or Array] params Data to write to command file pipe. Must
    #     include :action and all additional variables
    def write data
      case data
      when Hash then params = [params]
      else 
        return false
      end

      params.each do |params|
      end
      raise ArgumentError, "Action name must be provided" unless params.has_key? :action
      raise ArgumentError, "Action name #{params[:action]} is not implemented" unless ACTIONS.keys.include? params[:action]
      
      params.each { |k,v| self.instance_variable_set "@#{k}", v }

      #
      # Check that all variable that are used in the template are
      # actually set, not nil's
      #
      ACTIONS[@action].each do |var|
        raise ArgumentError, "Parameter :#{var} is required, cannot be nil" if self.instance_variable_get("@#{var}").nil?
      end

      self.ts = params[:ts] || Time.now.to_i.to_s

      format = "[#{ts}] " << ([self.action.to_s] + ACTIONS[self.action].map {|x| "<%= #{x} %>" }).join(';')
      
      File.open(path, 'a') do |pipe|
        pipe.puts ERB.new(format).result(self.get_binding)
        pipe.close
      end
      true
    end

  end
end

