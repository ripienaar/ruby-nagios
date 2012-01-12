#!/usr/bin/env ruby
#
# Check check- aggregate results from other checks in your nagios instance.
# Reads the 'status_file' for current states.
#
# Useful for having lots of small checks roll up into an aggregate that
# only alerts you once during failures, not N times.
#
# Also useful for business-view monitoring
#

require "rubygems"
require "nagios/status"
require "optparse"

class Nagios::Status::Model
  STATEMAP = {
    "0" => "OK",
    "1" => "WARNING",
    "2" => "CRITICAL",
    "3" => "UNKNOWN",
  }

  def initialize(path)
    @path = path
    @status = Nagios::Status.new
    update
  end # def initialize

  def update
    @status.parsestatus(@path)
  end # def update

  def services(service_pattern=nil, host_pattern=nil)
    matches = []
    self.hosts(host_pattern).each do |host, hostinfo|
      # Skip hosts if there is no hostinfo (no services associated, etc).
      next if hostinfo["servicestatus"].nil?
      # Skip hosts if they are in scheduled downtime
      next if hostinfo["hostdowntime"].to_i > 0
      hostinfo["servicestatus"].each do |name, status| 
        next if service_pattern and !service_pattern.match(name)

        # Skip myself, if we are a check running from nagios.
        next if name == ENV["NAGIOS_SERVICEDESC"]

        # Skip silenced or checks in scheduled downtime.
        next if status["notifications_enabled"].to_i == 0
        next if status["scheduled_downtime_depth"].to_i > 0

        # Only report checks that are in 'hard' state.
        # If not in hard state, report 'last_hard_state' instead.
        if status["state_type"] != "1" # not in hard state
          status["current_state"] = status["last_hard_state"]
          # TODO(sissel): record that this service is currently 
          # in a soft state transition.
        end

        # TODO(sissel): Maybe also skip checks that are 'acknowledged'
        matches << status
      end
    end # hosts().each 
    return matches
  end # def services

  def hosts(pattern=nil)
    if pattern
      return @status.status["hosts"].reject { |name,hostinfo| !pattern.match(name) }
    else
      return @status.status["hosts"]
    end # if pattern
  end # def hosts

  # TODO(sissel): add a proper 'status' model that
  # has HostStatus, ServiceStatus, etc.

end # class Nagios::Status::Model

Settings = Struct.new(:nagios_cfg, :status_path, :service_pattern, :host_pattern)
def main(args)
  progname = File.basename($0)
  settings = Settings.new
  settings.nagios_cfg = "/etc/nagios3/nagios.cfg" # debian/ubuntu default

  opts = OptionParser.new do |opts|
    opts.banner = "Usage: #{progname} [options]"

    opts.on("-f NAGIOS_CFG", "--config NAGIOS_CFG",
            "Path to your nagios.cfg (I will use the status_file setting") do |val|
      settings.nagios_cfg = val
    end

    opts.on("-s REGEX", "--service REGEX",
            "Aggregate only services matching the given pattern") do |val|
      settings.service_pattern = val
    end

    opts.on("-h REGEX", "--host REGEX",
            "Aggregate only services from hosts matching the given pattern") do |val|
      settings.host_pattern = val
    end
  end # OptionParser.new

  opts.parse!(args)

  # hacky parsing, for now
  status_line = File.new(settings.nagios_cfg, "r").readlines.grep(/^\s*status_file\s*=/).first.chomp
  settings.status_path = status_line.split(/\s*=\s*/)[1]
  status = Nagios::Status::Model.new(settings.status_path)

  results = Hash.new { |h,k| h[k] = 0 }
  service_pattern = nil
  if settings.service_pattern
    service_pattern = Regexp.new(settings.service_pattern)
  end

  host_pattern = nil
  if settings.host_pattern
    host_pattern = Regexp.new(settings.host_pattern)
  end

  Nagios::Status::Model::STATEMAP.values.each do |state|
    results[state] = []
  end

  # Collect check results by state
  status.services(service_pattern, host_pattern).each do |service_status|
    state = Nagios::Status::Model::STATEMAP[service_status["current_state"]] 
    if state == nil
      state = "UNKNOWN(state=#{service_status["current_state"]})"
    end

    results[state] << service_status
  end

  # Output a summary line
  ["OK", "WARNING", "CRITICAL", "UNKNOWN"].each do | state|
    print "#{state}=#{results[state].length} "
  end
  print "services=/#{settings.service_pattern}/ "
  print "hosts=/#{settings.host_pattern}/ "
  puts

  # More data output
  ["WARNING", "CRITICAL", "UNKNOWN"].each do |state|
    if results[state] && results[state].size > 0
      puts "Services in #{state}:"
      results[state].sort { |a,b| a["host_name"] <=> b["host_name"] }.each do |service|
        puts "  #{service["host_name"]} => #{service["service_description"]}"
      end
    end # if results[state]
  end # for each non-OK state

  exitcode = 0

  if results["WARNING"].length > 0
    exitcode = 1
  end

  if results["CRITICAL"].length > 0
    exitcode = 2
  end
  return exitcode
end

exit(main(ARGV))
