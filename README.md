What?
=====
Have you ever had to disable alerts, retry a check
or acknowledge outages on a large amount of service
with Nagios and hated the web UI for it?

This is a CLI tool and Ruby library that parses your
status log file and let you query it for information
or create external commands to be piped into the nagios
command file.

You can get this software here on GitHub or via RubyGems
as *ruby-nagios*

Using on the CLI?
=================
Find out what services match a regular expression:

    nagsrv --list-services --with-service /puppet/
    puppet-freshness
    puppetd
    puppetmaster

Find hosts with the service /puppet/:

    nagsrv --list-hosts --with-service /puppet/
    dev1.your.net
    dev2.your.net
    .
    .

Disable notifications for them all on all hosts:

    nagsrv.rb --disable-notify --with-service /puppet/
    [1263129006] DISABLE_SVC_NOTIFICATIONS;dev1.your.net;puppet-freshness
    [1263129006] DISABLE_SVC_NOTIFICATIONS;dev1.your.net;puppetd
    [1263129006] DISABLE_SVC_NOTIFICATIONS;dev1.your.net;puppet-freshness
    .
    .
    .

Only do it for hosts matching /dev2/:

    nagsrv.rb --disable-notify --with-service /puppet/ --for-host /dev2/
    [1263129038] DISABLE_SVC_NOTIFICATIONS;dev2.your.net;puppet-freshness
    [1263129038] DISABLE_SVC_NOTIFICATIONS;dev2.your.net;puppetd

You can do ack's, force checks etc, see the help or
comments in the nagsrv.rb script. To actually get
nagios to do these actions just redirect the output
from these commands to the Nagios CMD file. On my
machine that is /var/log/nagios/rw/nagios.cmd.

Using from Ruby?
================

You can also do the same from within Ruby easily,
the library lets you search host by any property
on a service, here we'll find all hosts with
service /puppet/ on host /dev2/:

    require 'rubygems'
    require 'nagios/status'
    nagios = Nagios::Status.new
    nagios.parsestatus("status.log")

    options = {:forhost => "/dev2/", :action => "${host}",
               :withservice => "/puppet/"}
    services = nagios.find_services(options)

    puts services.join("\n")

This will in this case just print:

    dev2.your.net

If you didn't specify the :action string it would
just return an array of services found. The :action
string is a template that lets you return the matches
in any format you like, here's a template to Acknowledge
services:

    "[${tstamp}] ACKNOWLEDGE_SVC_PROBLEM;;${host};${service};1 \
     ;0;1;#{ENV['USER']};Acknowledged from CLI"

The only variables it supports now is ${host}, ${service}
and ${tstamp} we can easily add more if needed.

Contact?
========

R.I.Pienaar / rip@devco.net / @ripienaar / http://devco.net/
