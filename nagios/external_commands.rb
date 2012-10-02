module Nagios


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
  #     command.send :action => :PROCESS_HOST_CHECK_RESULT, 
  #       :host_name  => 'myhost', :status_code => 0, :plugin_output => "PING command OK"
  #
  class ExternalCommands

    require 'erb'

    # External commands list in nagios and format to send this to
    # Nagios. Keys of the Hash are names of commands, values are
    # Array's of Nagios varables to be sent. Arrays are converted to
    # ERB templates before printing, command name and all varibles
    # joined together by semicolons.
    #
    # Each variable must be defined as attr_accessor, these variables
    # are used in ERB binding.
    #
    # List of all available nagios external commands, formats and
    # descripttions can be obtained from
    # http://www.nagios.org/developerinfo/externalcommands As of the
    # time of writing this list is 157 commands for Nagios 3.x.
    #
    # == Example
    #
    #     PROCESS_SERVICE_CHECK_RESULT: %w{host_name service_description return_code plugin_output} 
    #
    #     converted to template on print:
    #
    #     [timestamp] PROCESS_SERVICE_CHECK_RESULT;<%= host_name %>;<%= service_description %>;<%= return_code %>;<%= plugin_output %>\n
    #
    ACTIONS = { 
      ACKNOWLEDGE_HOST_PROBLEM: %w{host_name sticky notify persistent author comment},
      ACKNOWLEDGE_SVC_PROBLEM: %w{host_name service_description sticky notify persistent author comment},
      ADD_HOST_COMMENT: %w{host_name persistent author comment},
      ADD_SVC_COMMENT: %w{host_name service_description persistent author comment},
      CHANGE_CONTACT_HOST_NOTIFICATION_TIMEPERIOD: %w{contact_name notification_timeperiod},
      CHANGE_CONTACT_MODATTR: %w{contact_name value},
      CHANGE_CONTACT_MODHATTR: %w{contact_name value},
      CHANGE_CONTACT_MODSATTR: %w{contact_name value},
      CHANGE_CONTACT_SVC_NOTIFICATION_TIMEPERIOD: %w{contact_name notification_timeperiod},
      CHANGE_CUSTOM_CONTACT_VAR: %w{contact_name varname varvalue},
      CHANGE_CUSTOM_HOST_VAR: %w{host_name varname varvalue},
      CHANGE_CUSTOM_SVC_VAR: %w{host_name service_description varname varvalue},
      CHANGE_GLOBAL_HOST_EVENT_HANDLER: %w{event_handler_command},
      CHANGE_GLOBAL_SVC_EVENT_HANDLER: %w{event_handler_command},
      CHANGE_HOST_CHECK_COMMAND: %w{host_name check_command},
      CHANGE_HOST_CHECK_TIMEPERIOD: %w{host_name check_timeperod},
      CHANGE_HOST_CHECK_TIMEPERIOD: %w{host_name timeperiod},
      CHANGE_HOST_EVENT_HANDLER: %w{host_name event_handler_command},
      CHANGE_HOST_MODATTR: %w{host_name value},
      CHANGE_MAX_HOST_CHECK_ATTEMPTS: %w{host_name check_attempts},
      CHANGE_MAX_SVC_CHECK_ATTEMPTS: %w{host_name service_description check_attempts},
      CHANGE_NORMAL_HOST_CHECK_INTERVAL: %w{host_name check_interval},
      CHANGE_NORMAL_SVC_CHECK_INTERVAL: %w{host_name service_description check_interval},
      CHANGE_RETRY_HOST_CHECK_INTERVAL: %w{host_name service_description check_interval},
      CHANGE_RETRY_SVC_CHECK_INTERVAL: %w{host_name service_description check_interval},
      CHANGE_SVC_CHECK_COMMAND: %w{host_name service_description check_command},
      CHANGE_SVC_CHECK_TIMEPERIOD: %w{host_name service_description check_timeperiod},
      CHANGE_SVC_EVENT_HANDLER: %w{host_name service_description event_handler_command},
      CHANGE_SVC_MODATTR: %w{host_name service_description value},
      CHANGE_SVC_NOTIFICATION_TIMEPERIOD: %w{host_name service_description notification_timeperiod},
      DELAY_HOST_NOTIFICATION: %w{host_name notification_time},
      DELAY_SVC_NOTIFICATION: %w{host_name service_description notification_time},
      DEL_ALL_HOST_COMMENTS: %w{host_name},
      DEL_ALL_SVC_COMMENTS: %w{host_name service_description},
      DEL_HOST_COMMENT: %w{comment_id},
      DEL_HOST_DOWNTIME: %w{downtime_id},
      DEL_SVC_COMMENT: %w{comment_id},
      DEL_SVC_DOWNTIME: %w{downtime_id},
      DISABLE_ALL_NOTIFICATIONS_BEYOND_HOST: %w{host_name},
      DISABLE_CONTACTGROUP_HOST_NOTIFICATIONS: %w{contactgroup_name},
      DISABLE_CONTACTGROUP_SVC_NOTIFICATIONS: %w{contactgroup_name},
      DISABLE_CONTACT_HOST_NOTIFICATIONS: %w{contact_name},
      DISABLE_CONTACT_SVC_NOTIFICATIONS: %w{contact_name},
      DISABLE_EVENT_HANDLERS: [],
      DISABLE_FAILURE_PREDICTION: [],
      DISABLE_FLAP_DETECTION: [],
      DISABLE_HOSTGROUP_HOST_CHECKS: %w{hostgroup_name},
      DISABLE_HOSTGROUP_HOST_NOTIFICATIONS: %w{hostgroup_name},
      DISABLE_HOSTGROUP_PASSIVE_HOST_CHECKS: %w{hostgroup_name},
      DISABLE_HOSTGROUP_PASSIVE_SVC_CHECKS: %w{hostgroup_name},
      DISABLE_HOSTGROUP_SVC_CHECKS: %w{hostgroup_name},
      DISABLE_HOSTGROUP_SVC_NOTIFICATIONS: %w{hostgroup_name},
      DISABLE_HOST_AND_CHILD_NOTIFICATIONS: %w{host_name},
      DISABLE_HOST_CHECK: %w{host_name},
      DISABLE_HOST_EVENT_HANDLER: %w{host_name},
      DISABLE_HOST_FLAP_DETECTION: %w{host_name},
      DISABLE_HOST_FRESHNESS_CHECKS: [],
      DISABLE_HOST_NOTIFICATIONS: %w{host_name},
      DISABLE_HOST_SVC_CHECKS: %w{host_name},
      DISABLE_HOST_SVC_NOTIFICATIONS: %w{host_name},
      DISABLE_NOTIFICATIONS: [],
      DISABLE_PASSIVE_HOST_CHECKS: %w{host_name},
      DISABLE_PASSIVE_SVC_CHECKS: %w{host_name service_description},
      DISABLE_PERFORMANCE_DATA: [],
      DISABLE_SERVICEGROUP_HOST_CHECKS: %w{servicegroup_name},
      DISABLE_SERVICEGROUP_HOST_NOTIFICATIONS: %w{servicegroup_name},
      DISABLE_SERVICEGROUP_PASSIVE_HOST_CHECKS: %w{servicegroup_name},
      DISABLE_SERVICEGROUP_PASSIVE_SVC_CHECKS: %w{servicegroup_name},
      DISABLE_SERVICEGROUP_SVC_CHECKS: %w{servicegroup_name},
      DISABLE_SERVICEGROUP_SVC_NOTIFICATIONS: %w{servicegroup_name},
      DISABLE_SERVICE_FLAP_DETECTION: %w{host_name service_description},
      DISABLE_SERVICE_FRESHNESS_CHECKS: [],
      DISABLE_SVC_CHECK: %w{host_name service_description},
      DISABLE_SVC_EVENT_HANDLER: %w{host_name service_description},
      DISABLE_SVC_FLAP_DETECTION: %w{host_name service_description},
      DISABLE_SVC_NOTIFICATIONS: %w{host_name service_description},
      ENABLE_ALL_NOTIFICATIONS_BEYOND_HOST: %w{host_name},
      ENABLE_CONTACTGROUP_HOST_NOTIFICATIONS: %w{contactgroup_name},
      ENABLE_CONTACTGROUP_SVC_NOTIFICATIONS: %w{contactgroup_name},
      ENABLE_CONTACT_HOST_NOTIFICATIONS: %w{contact_name},
      ENABLE_CONTACT_SVC_NOTIFICATIONS: %w{contact_name},
      ENABLE_EVENT_HANDLERS: [],
      ENABLE_FAILURE_PREDICTION: [],
      ENABLE_FLAP_DETECTION: [],
      ENABLE_HOSTGROUP_HOST_CHECKS: %w{hostgroup_name},
      ENABLE_HOSTGROUP_HOST_NOTIFICATIONS: %w{hostgroup_name},
      ENABLE_HOSTGROUP_PASSIVE_HOST_CHECKS: %w{hostgroup_name},
      ENABLE_HOSTGROUP_PASSIVE_SVC_CHECKS: %w{hostgroup_name},
      ENABLE_HOSTGROUP_SVC_CHECKS: %w{hostgroup_name},
      ENABLE_HOSTGROUP_SVC_NOTIFICATIONS: %w{hostgroup_name},
      ENABLE_HOST_AND_CHILD_NOTIFICATIONS: %w{host_name},
      ENABLE_HOST_CHECK: %w{host_name},
      ENABLE_HOST_EVENT_HANDLER: %w{host_name},
      ENABLE_HOST_FLAP_DETECTION: %w{host_name},
      ENABLE_HOST_FRESHNESS_CHECKS: [],
      ENABLE_HOST_NOTIFICATIONS: %w{host_name},
      ENABLE_HOST_SVC_CHECKS: %w{host_name},
      ENABLE_HOST_SVC_NOTIFICATIONS: %w{host_name},
      ENABLE_NOTIFICATIONS: [],
      ENABLE_PASSIVE_HOST_CHECKS: %w{host_name},
      ENABLE_PASSIVE_SVC_CHECKS: %w{host_name service_description},
      ENABLE_PERFORMANCE_DATA: [],
      ENABLE_SERVICEGROUP_HOST_CHECKS: %w{servicegroup_name},
      ENABLE_SERVICEGROUP_HOST_NOTIFICATIONS: %w{servicegroup_name},
      ENABLE_SERVICEGROUP_PASSIVE_HOST_CHECKS: %w{servicegroup_name},
      ENABLE_SERVICEGROUP_PASSIVE_SVC_CHECKS: %w{servicegroup_name},
      ENABLE_SERVICEGROUP_SVC_CHECKS: %w{servicegroup_name},
      ENABLE_SERVICEGROUP_SVC_NOTIFICATIONS: %w{servicegroup_name},
      ENABLE_SERVICE_FRESHNESS_CHECKS: [],
      ENABLE_SVC_CHECK: %w{host_name service_description},
      ENABLE_SVC_EVENT_HANDLER: %w{host_name service_description},
      ENABLE_SVC_FLAP_DETECTION: %w{host_name service_description},
      ENABLE_SVC_NOTIFICATIONS: %w{host_name service_description},
      PROCESS_FILE: %w{file_name delete},
      PROCESS_HOST_CHECK_RESULT: %w{host_name status_code plugin_output},
      PROCESS_SERVICE_CHECK_RESULT: %w{host_name service_description return_code plugin_output},
      READ_STATE_INFORMATION: [],
      REMOVE_HOST_ACKNOWLEDGEMENT: %w{host_name},
      REMOVE_SVC_ACKNOWLEDGEMENT: %w{host_name service_description},
      RESTART_PROGRAM: [],
      SAVE_STATE_INFORMATION: [],
      SCHEDULE_AND_PROPAGATE_HOST_DOWNTIME: %w{host_name start_time end_time fixed trigger_id duration author comment},
      SCHEDULE_AND_PROPAGATE_TRIGGERED_HOST_DOWNTIME: %w{host_name start_time end_time fixed trigger_id duration author comment},
      SCHEDULE_FORCED_HOST_CHECK: %w{host_name check_time},
      SCHEDULE_FORCED_HOST_SVC_CHECKS: %w{host_name check_time},
      SCHEDULE_FORCED_SVC_CHECK: %w{host_name service_description check_time},
      SCHEDULE_HOSTGROUP_HOST_DOWNTIME: %w{hostgroup_name start_time end_time fixed trigger_id duration author comment},
      SCHEDULE_HOSTGROUP_SVC_DOWNTIME: %w{hostgroup_name start_time end_time fixed trigger_id duration author comment},
      SCHEDULE_HOST_CHECK: %w{host_name check_time},
      SCHEDULE_HOST_DOWNTIME: %w{host_name start_time end_time fixed trigger_id duration author comment},
      SCHEDULE_HOST_SVC_CHECKS: %w{host_name check_time},
      SCHEDULE_HOST_SVC_DOWNTIME: %w{host_name start_time end_time fixed trigger_id duration author comment},
      SCHEDULE_SERVICEGROUP_HOST_DOWNTIME: %w{servicegroup_name start_time end_time fixed trigger_id duration author comment},
      SCHEDULE_SERVICEGROUP_SVC_DOWNTIME: %w{servicegroup_name start_time end_time fixed trigger_id duration author comment},
      SCHEDULE_SVC_CHECK: %w{host_name service_description check_time},
      SCHEDULE_SVC_DOWNTIME: %w{host_name service_desription><start_time end_time fixed trigger_id duration author comment},
      SEND_CUSTOM_HOST_NOTIFICATION: %w{host_name options author comment},
      SEND_CUSTOM_SVC_NOTIFICATION: %w{host_name service_description options author comment},
      SET_HOST_NOTIFICATION_NUMBER: %w{host_name notification_number},
      SET_SVC_NOTIFICATION_NUMBER: %w{host_name service_description notification_number},
      SHUTDOWN_PROGRAM: [],
      START_ACCEPTING_PASSIVE_HOST_CHECKS: [],
      START_ACCEPTING_PASSIVE_SVC_CHECKS: [],
      START_EXECUTING_HOST_CHECKS: [],
      START_EXECUTING_SVC_CHECKS: [],
      START_OBSESSING_OVER_HOST: %w{host_name},
      START_OBSESSING_OVER_HOST_CHECKS: [],
      START_OBSESSING_OVER_SVC: %w{host_name service_description},
      START_OBSESSING_OVER_SVC_CHECKS: [],
      STOP_ACCEPTING_PASSIVE_HOST_CHECKS: [],
      STOP_ACCEPTING_PASSIVE_SVC_CHECKS: [],
      STOP_EXECUTING_HOST_CHECKS: [],
      STOP_EXECUTING_SVC_CHECKS: [],
      STOP_OBSESSING_OVER_HOST: %w{host_name},
      STOP_OBSESSING_OVER_HOST_CHECKS: [],
      STOP_OBSESSING_OVER_SVC: %w{host_name service_description},
      STOP_OBSESSING_OVER_SVC_CHECKS: []
    }


    # Constructor for teh external commnd send class.
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

      format = "[#{ts}] " << ([self.action.to_s] + ACTIONS[self.action].map {|x| "<%= #{x} %>" }).join(';')
      
      File.open(path, 'a') do |pipe|
        pipe.puts ERB.new(format).result(self.get_binding)
        pipe.close
      end
      true
    end

  end
end

