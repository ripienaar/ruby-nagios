module Nagios

=begin rdoc

= DESCRIPTION

Nagios::Objects -- class for parsing Nagios' objects.cache
file. Objects.cache file keeps information about lists of objects
being monitored by Nagios. It is created by Nagios process on
(re)start. Since it is machine-generated file syntax should not vary
from file to file.

Class implements 2 methods at the time of writing:
* constructor - that only creates an instance and
* parse method - that does actual parsing and populates instance variable @objects

= SYNOPSIS

  require 'nagios/objects'
 
   a = Nagios::Objects.new("test/objects.cache").new.parse
   print a.objects[:contactgroup]

== Files

Location of objects.cache file depends on Nagios configuration (in
many cases varies from one UNIX/Linux ditribution to another) and is
defined by directive in nagios.cfg file. 

On Debian system objects.cache it is in
/var/cache/nagios3/objects.cache:

  object_cache_file=/var/cache/nagios3/objects.cache

= Author

Dmytro Kovalov, dmytro.kovalov@gmail.com
2011, Dec, 27 - First working version

=end

  class Objects

    # @param [String] path UNIX path to the objects.cache file
    def initialize path
      raise "File does not exist" unless File.exist? path
      raise "File is not readable" unless File.readable? path
      @objects_file = path
      @objects = {}
    end
 
    # PATH to the objects.cache file
    attr_accessor :objects_file

    # Parsed objects
    attr_accessor :objects


=begin rdoc    

Read objects.cache file and parse it.

Method reads file by blocks. Each block defines one object, definition
starts with 'define <type> {' and ends with '}'. Each block has a
'<type>_name' line which defines name of the instance of the
object. 

Code of the 'parse()' method assumes, that _name line is always first
in the block! This can be not always the case.

Example of a block:

  define contactgroup {
          contactgroup_name       admins
          alias   Nagios Administrators
          members root
          }

Parsed data hash:

    irb(main):010:0> pp a.objects
     {:timeperiod=>
      {"24x7"=>
        {:timeperiod_name=>"24x7",
         :alias=>"24 Hours A Day, 7 Days A Week",
         :sunday=>"00:00-24:00",
         :monday=>"00:00-24:00",
         :tuesday=>"00:00-24:00",
         :wednesday=>"00:00-24:00",
         :thursday=>"00:00-24:00",
         :friday=>"00:00-24:00",
         :saturday=>"00:00-24:00"},
       "never"=>{:timeperiod_name=>"never", :alias=>"Never"},
    
=end

    def parse
      block = {}
      content = File.readlines objects_file
      handler = nil
      content.each do |line|
        case
        when line =~ /^\s*$/ then next # Skip empty lines
        when line =~ /^\s*#/ then next # Skip comments
        when line =~ /(\w+) \{/        # Block starts as "define host {"
          block = {}
          handler = $1.to_sym
        when line =~ /\}/              # End of block
          #
          # Process it. Each block type has line <type>_name in the definition: host_name, command_name
          #
          @objects[handler] ||= {}
          @objects[handler][block["#{handler.to_s}_name".to_sym]] = block 
          block = { }
       when line =~ /^\s*(\w+)\s+([^\{\}]+)$/  # Build Hash from key-value pairs like: "max_check_attempts      10"
          block[$1.to_sym] = $2.strip
        end
      end
    end
 
  end
end

