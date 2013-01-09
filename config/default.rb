module Nagios

  DEFAULT = { 
    :nagios_cfg_glob => ENV['NAGIOS_CFG_FILE'] || 
    [
     "/etc/nagios*/nagios.cfg", 
     "/usr/local/nagios/etc/nagios.cfg"
    ]
  }

end
