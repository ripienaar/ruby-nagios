#!/usr/bin/env ruby
#
# Check check.
#
# Aggregate results from other checks in your nagios instance.
# Reads the 'status_file' for current states
#

require "nagios/status"
require "optparse"

class Nagios::Status::Model
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
      hostinfo["servicestatus"].each do |name, status| 
        next if service_pattern and !service_pattern.match(name)

        # Skip silenced or checks in scheduled downtime.
        next if status["notifications_enabled"].to_i == 0
        next if status["scheduled_downtime_depth"].to_i > 0
        # TODO(sissel): Maybe also skip checks that are 'acknowledged'
        matches << status
      end
    end # hosts().each 
    return matches
  end # def services

  def hosts(pattern=nil)
    if pattern
      return @status.status["hosts"]
      #.reject { |name,hostinfo| !pattern.match(name) }
    else
      return @status.status["hosts"]
    end # if pattern
  end # def hosts

  # TODO(sissel): add a proper 'status' model that
  # has HostStatus, ServiceStatus, etc.

end # class Nagios::Status::Model

def main(args)
  progname = File.basename($0)
  Settings = Struct.new(:nagios_cfg, :status_path, :service_pattern, :host_pattern)
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
  status_line = File.readlines(settings.nagios_cfg, "r").grep(/^\s*status_file/)
  settings.status_path = status_line.split(/\s*=\s*/)[1]
  status = Nagios::Status::Model.new(settings.status_path)

  results = Hash.new { |h,k| h[k] = 0 }
  if settings.service_pattern
    settings.service_pattern = Regexp.new(settings.service_pattern)
  end

  if settings.host_pattern
    settings.host_pattern = Regexp.new(settings.host_pattern)
  end

  status.services(service_pattern, host_pattern).each do |service_status|
    results[service_status["current_state"]] += 1
  end
  ap status.services(service_pattern)

  return 0
end

exit(main(ARGV))
