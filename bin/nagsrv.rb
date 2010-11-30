#!/usr/bin/ruby

# A tool to do mass operations on nagios services.  It is intended to be run on 
# the server that hosts nagios and it needs read access to the status.log file
# typically found in the var dir.
#
# Command options are broken up into several types:
#
# == General
# --statusfile
#   Where to find the status file
#
# == Output Selectors
# --list-hosts
#   List hostnames that match certain criteria
#
# --list-service
#   List services that match certain criteria
#
# == Selectors
# --with-service
#   Pass a specific service name or a regex in the form
#   /pattern/ if you pass a regex you can only pass this
#   option once, if you pass specific services you can 
#   use this option many times the services will be searches
#   in an OR fasion
#
# --for-host
#   Restrict the selection of services to a specific host or
#   regex match of hosts, same regex rules as for --with-service
#
# --notify-enabled
#   List only services with notifications enabled, in this mode
#   the output will be in the form host:service
#
# == Actions
# --enable-notify / --disable-notify
#   Enable or Disable notifications for selected services
#
# --enable-checks / --disable-checks
#   Enable of Disable checks for selected services
#
# --force-check
#   Force checks for selected services
#
# --acknowledge
#   Ackknowledge services without sending notifies
#
# Released under the terms of the Apache version 2 
# license
#
# Please open an issue at ruby-nagios.googlecode.com
# with any queries

require 'nagios/status.rb'

require 'getoptlong'

def showhelp
    begin  
        require 'rdoc/ri/ri_paths'
        require 'rdoc/usage'  
        RDoc::usage
    rescue LoadError
        puts ("Install RDoc::usage or view the comments in the top of the script to get detailed help")
    end
end

opts = GetoptLong.new(
    [ '--statusfile', '-s', GetoptLong::REQUIRED_ARGUMENT],
    [ '--list-hosts', GetoptLong::NO_ARGUMENT],
    [ '--list-services', GetoptLong::NO_ARGUMENT],
    [ '--notify-enabled', GetoptLong::NO_ARGUMENT],
    [ '--notify-disabled', GetoptLong::NO_ARGUMENT],
    [ '--for-host', GetoptLong::REQUIRED_ARGUMENT],
    [ '--with-service', GetoptLong::REQUIRED_ARGUMENT],
    [ '--enable-notify', GetoptLong::NO_ARGUMENT],
    [ '--disable-notify', GetoptLong::NO_ARGUMENT],
    [ '--enable-checks', GetoptLong::NO_ARGUMENT],
    [ '--disable-checks', GetoptLong::NO_ARGUMENT],
    [ '--force-check', GetoptLong::NO_ARGUMENT],
    [ '--acknowledge', GetoptLong::NO_ARGUMENT]
)

statusfile = "status.log"
listhosts = false
withservice = []
listservices = false
forhost = []
notify = nil
action = nil
options = nil

begin
    opts.each do |opt, arg|
        case opt
            when "--statusfile"
                statusfile = arg
            when "--list-hosts"
                listhosts = true
            when "--list-services"
                listservices = true
            when "--with-service"
                withservice << arg
            when "--for-host"
                forhost << arg
            when "--enable-notify"
                action = "[${tstamp}] ENABLE_SVC_NOTIFICATIONS;${host};${service}"
            when "--disable-notify"
                action = "[${tstamp}] DISABLE_SVC_NOTIFICATIONS;${host};${service}"
            when "--force-check"
                action = "[${tstamp}] SCHEDULE_FORCED_SVC_CHECK;${host};${service};${tstamp}"
            when "--enable-checks"
                action = "[${tstamp}] ENABLE_SVC_CHECK;${host};${service};${tstamp}"
            when "--disable-checks"
                action = "[${tstamp}] DISABLE_SVC_CHECK;${host};${service};${tstamp}"
            when "--acknowledge"
                action = "[${tstamp}] ACKNOWLEDGE_SVC_PROBLEM;${host};${service};1;0;1;#{ENV['USER']};Acknowledged from CLI"
            when "--notify-enabled"
                notify = 1
            when "--notify-disabled"
                notify = 0
        end
    end
rescue 
    showhelp
    exit 1
end


nagios = Nagios::Status.new

nagios.parsestatus(statusfile)


# We want hosts so abuse the action field to print just the hostname
# and select all hosts unless other action/forhost was desigred then
# this really is just a noop and it reverts to noral behaviour
if listhosts
    action = "${host}" if action == nil
    forhost = "/." if forhost.size == 0
end

options = {:forhost => forhost, :notifyenabled => notify, :action => action, :withservice => withservice}
services = nagios.find_services(options)

puts services.join("\n")

# vi:tabstop=4:expandtab:ai
