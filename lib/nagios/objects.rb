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
 
   nagios = Nagios::Objects.new("test/objects.cache").new.parse
   print nagios.objects[:contactgroup]

== Files

Location of objects.cache file depends on Nagios configuration (in
many cases varies from one UNIX/Linux ditribution to another) and is
defined by directive in nagios.cfg file. 

On Debian system objects.cache it is in
/var/cache/nagios3/objects.cache:

  object_cache_file=/var/cache/nagios3/objects.cache

== Parsed data hash

    irb(main):010:0> pp nagios.objects
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

= Author

Dmytro Kovalov, dmytro.kovalov@gmail.com
2011, Dec, 27 - First working version

=end

  class Objects

    # @param [String] path UNIX path to the objects.cache file
    # @see Nagios::Objects.parse
    def initialize path
      raise "File #{path} does not exist" unless File.exist? path
      raise "File #{path} is not readable" unless File.readable? path
      @path = path
      @objects = {}
    end
 
    # PATH to the objects.cache file
    attr_accessor :path

    # Parsed objects
    attr_accessor :objects


=begin rdoc    

Read objects.cache file and parse it.

Method reads file by blocks. Each block defines one object, definition
starts with 'define <type> !{' and ends with '}'. Each block has a
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

Example of a parsed object:

    nagios.objects[:contactgroup]
    => {"admins"=>{:contactgroup_name=>"admins", :alias=>"Nagios Administrators", :members=>"root"}}

    nagios.contactgroup
    => {"admins"=>{:contactgroup_name=>"admins", :alias=>"Nagios Administrators", :members=>"root"}}

=== Convenience methods

Method parse creates helper methods for every type of object after
parsing. Same property can be accessed either using Hash @objects
(i.e. nagios.objects[:host]) or convenience method: nagios.host.

=end
    def parse
      block = {}
      content = File.readlines path
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

      # Create instance methods for easy access to properties
      @objects.each do |key,val|
        instance_variable_set("@#{key}", val)
        instance_eval "def #{key}; return #{val}; end"
      end
      self
    end

    # Basic find function for resources.
    # @param [Symbol] resource Resource to search from: :host, :hostgroup, etc.
    # @param [Symbol] attribute Attribute to use in search. For example, find host by hostname or address, etc. anything that's defined for this resource
    # @param [Symbol] message  Is either 'find' or 'find_all' passed from caller. In case of 'find' returns 1 hash, 'find_all' - Array of Hash'es.
    #
    # @param [String, Regexp] pattern Search pattern
    
    def find resource, message, attribute, pattern
      self.send(resource.to_sym).values.send(message) do |a| 
        case pattern
        when String
          a[attribute.to_sym] == pattern
        when Regexp
          a[attribute.to_sym] =~ pattern
        else
          raise 'Unknown pattern for search'
        end
        
      end
    end

    # Replace standard +method_missing+ with dynamic search methods. Calls internally self.find.
    #
    # @see find
    #
    # @param [Symbol] sym Should be in the form
    #     find(_all)?_<resource>_by_<attribute>. Similar to
    #     ActiveResource find_* dynamic methods. Depending on the name
    #     of the method called (find or find_all) will pass message to
    #     self.find method, that will call Array#find or
    #     Array.find_all accordingly.
    #
    # find_*_by and find_all_*. find_all returns Array of
    # hashes. 

    def method_missing sym, *args, &block
      raise(NoMethodError, "No such method #{sym.to_s} for #{self.class}") unless sym.to_s =~ /^(find(_all)?)_(.*)_by_(.*)$/
      # message - either 'find' of 'find_all'
      # resource - type of objects to search: host, hostgroup etc.
      # attribute - name of the attribute to do search by: :host_name, :check_command
      # @param *args String or Regexp to search objects
      message,resource,attribute  = $1, $3, $4

      self.find resource,message,attribute,args[0]
    end

  end
end

