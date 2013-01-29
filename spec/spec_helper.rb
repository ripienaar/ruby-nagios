
TEST = if ENV['RSPEC_ENV'] == 'test'
         { 
    :nagios_cfg => 'test/data/nagios.cfg',
    :status_file => 'test/data/status.dat',
    :object_cache_file  => 'test/data/objects.cache',
  }
       else
         { 
    :nagios_cfg => nil,
    :status_file => nil,
    :object_cache_file  => nil
  }
       end
