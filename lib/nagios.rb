module Nagios

  DEFAULT = { 
    :nagios_cfg_glob => ENV['NAGIOS_CFG_FILE'] || 
    [
     "/etc/nagios*/nagios.cfg", 
     "/usr/local/nagios/etc/nagios.cfg"
    ]
  }

end

require 'nagios/config'
require 'nagios/external_commands'
require 'nagios/objects'
require 'nagios/status'

class String
  unless method_defined?("each")
    alias_method :each, :each_line
  end
end
$: << File.dirname(__FILE__)

