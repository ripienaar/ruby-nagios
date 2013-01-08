
if ENV['RACK_ENV'] == 'test'
  TEST = { 
    :nagios_cfg => 'test/data/nagios.cfg',
    :status_file => 'test/data/status.dat',
    :object_cache_file  => 'test/data/objects.cache',
  }
else
end
