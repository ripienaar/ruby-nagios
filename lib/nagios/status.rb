module Nagios
  class Status
    attr_reader :status, :path

    def initialize(statusfile = nil)
      if statusfile
        fail ArgumentError, "Statusfile file name must be provided" unless statusfile
        fail "Statusfile #{statusfile} does not exist" unless File.exist? statusfile
        fail "Statusfile #{statusfile} is not readable" unless File.readable? statusfile
        @path = statusfile
      end
      @status = {'hosts' => { }}

      self
    end

    # Parses a nagios status file returning a data structure for all the data
    def parsestatus(path = nil)
      path ||= @path
      fail ArgumentError, "Statusfile file name must be provided either in constructor or as argument to parsestatus method" unless path

      @status = {'hosts' => {}}
      handler = ''
      blocklines = []

      File.readlines(path, encoding: 'iso-8859-1').each do |line|
        # start of new sections
        if line =~ /(\w+) \{/
          blocklines = []
          handler = Regexp.last_match(1)
        end

        # gather all the lines for the block into an array
        # we'll pass them to a handler for this kind of block
        blocklines << line if line =~ /\s+(\w+)=(.+)/ && handler != ""

        # end of a section
        if line =~ /\}/ && handler != "" && self.respond_to?("handle_#{handler}", include_private = true)
          send "handle_#{handler}".to_sym, blocklines
          handler = ""
        end
      end
      self
    end

    alias_method :parse, :parsestatus

    # Returns a list of all hosts matching the options in options
    def find_hosts(options = {})
      forhost = options.fetch(:forhost, [])
      notifications = options.fetch(:notifyenabled, nil)
      action = options.fetch(:action, nil)
      withservice = options.fetch(:withservice, [])

      hosts = []
      searchquery = []

      # Build up a search query for find_with_properties each
      # array member is a hash of property and a match
      forhost.each do |host|
        searchquery << search_term("host_name", host)
      end

      withservice.each do |s|
        searchquery << search_term("service_description", s)
      end

      searchquery << {"notifications_enabled" => notifications.to_s} if notifications

      hsts = find_with_properties(searchquery)

      hsts.each do |host|
        host_name = host["host_name"]

        hosts << parse_command_template(action, host_name, "", host_name)
      end

      hosts.uniq.sort
    end

    # Returns a list of all services matching the options in options
    def find_services(options = {})
      forhost = options.fetch(:forhost, [])
      notifications = options.fetch(:notifyenabled, nil)
      action = options.fetch(:action, nil)
      withservice = options.fetch(:withservice, [])
      acknowledged = options.fetch(:acknowledged, nil)
      passive = options.fetch(:passive, nil)
      current_state = options.fetch(:current_state, nil)
      json = options.fetch(:json, false)
      details = options.fetch(:details, false)

      services = []
      searchquery = []

      # Build up a search query for find_with_properties each
      # array member is a hash of property and a match
      forhost.each do |host|
        searchquery << search_term("host_name", host)
      end

      withservice.each do |s|
        searchquery << search_term("service_description", s)
      end

      searchquery << {"current_state" => current_state } if current_state
      searchquery << {"notifications_enabled" => notifications.to_s} if notifications
      searchquery << {"problem_has_been_acknowledged" => acknowledged.to_s} if acknowledged
      if passive
        searchquery << {"active_checks_enabled"  => 0}
        searchquery << {"passive_checks_enabled" => 1}
      end

      svcs = find_with_properties(searchquery)

      svcs.each do |service|
        service_description = service["service_description"]
        host_name = service["host_name"]

        # when printing services with notifications en/dis it makes
        # most sense to print them in host:service format, abuse the
        # action option to get this result
        action = "${host}:${service}" if !notifications.nil? && action.nil?

        services << parse_command_template(action, host_name, service_description, service_description)
      end

      if json
        [ "[", svcs.join(", \n").gsub("=>", ":"), "]" ]
      elsif details
        space = ' ' * 100
        delim = ' '
        state = ['OK', 'Warning', 'Critical', 'Unknown']
        details = []
        svcs.each do |s|
          details << (s['host_name'] + space)[0, 25] + delim \ + (s['service_description'] + space)[0, 35] + delim \ + (state[s['current_state'].to_i].to_s + space)[0, 8] + delim \ + (s['plugin_output'] + space)[0, 120]
        end
        details

      else
        services.uniq.sort
      end
    end

    private

    # Add search terms, does all the mangling of regex vs string and so on
    def search_term(haystack, needle)
      needle = Regexp.new(needle.delete("\/")) if needle.match("^/")
      {haystack => needle}
    end

    # Return service blocks for each service that matches any options like:
    #
    # "host_name" => "foo.com"
    #
    # The 2nd parameter can be a regex too.
    def find_with_properties(search)
      services = []
      query = []

      query << search if search.class == Hash
      query = search if search.class == Array

      @status["hosts"].each do |host, _v|
        find_host_services(host) do |service|
          matchcount = 0

          query.each do |q|
            q.each do |option, match|
              if match.class == Regexp
                matchcount += 1 if service[option].match(match)
              else
                matchcount += 1 if service[option] == match.to_s
              end
            end
          end

          services << service if matchcount == query.size
        end
      end

      services
    end

    # yields the hash for each service on a host
    def find_host_services(host)
      if @status["hosts"][host].key?("servicestatus")
        @status["hosts"][host]["servicestatus"].each do |s, _v|
          yield(@status["hosts"][host]["servicestatus"][s])
        end
      end
    end

    # Parses a template given with a nagios command string and populates vars
    # else return the string given in default
    def parse_command_template(template, host, service, default)
      if template.nil?
        default
      else
        template.gsub(/\$\{host\}/, host).gsub(/\$\{service\}/, service).gsub(/\$\{tstamp\}/, Time.now.to_i.to_s)
      end
    end

    # Figures out the service name from a block in a nagios status file
    def get_service_name(lines)
      if s = lines.grep(/\s+service_description=(\S+)/).first
        if s =~ /service_description=(.+)$/
          service = Regexp.last_match(1)
        else
          fail("Cant't parse service in block: #{s}")
        end
      else
        fail("Cant't find a service in block")
      end

      service
    end

    # Figures out the host name from a block in a nagios status file
    def get_host_name(lines)
      if h = lines.grep(/\s+host_name=(\w+)/).first
        if h =~ /host_name=(.+)$/
          host = Regexp.last_match(1)
        else
          fail("Cant't parse hostname in block: #{h}")
        end
      else
        fail("Cant't find a hostname in block")
      end

      host
    end

    # Parses an info block
    def handle_info(lines)
      @status["info"] = {} unless @status["info"]

      lines.each do |l|
        @status["info"][Regexp.last_match(1)] = Regexp.last_match(2) if l =~ /\s+(\w+)=(\w+)/
      end
    end

    # Parses a servicestatus block
    def handle_servicestatus(lines)
      host = get_host_name(lines)
      service = get_service_name(lines)

      @status["hosts"][host] = {} unless @status["hosts"][host]
      @status["hosts"][host]["servicestatus"] = {} unless @status["hosts"][host]["servicestatus"]
      @status["hosts"][host]["servicestatus"][service] = {} unless @status["hosts"][host]["servicestatus"][service]

      lines.each do |l|
        if l =~ /\s+(\w+)=(.+)$/
          if Regexp.last_match(1) == "host_name"
            @status["hosts"][host]["servicestatus"][service][Regexp.last_match(1)] = host
          else
            @status["hosts"][host]["servicestatus"][service][Regexp.last_match(1)] = Regexp.last_match(2)
          end
        end
      end
    end

    # Parses a servicestatus block
    def handle_contactstatus(lines)
      @status['contacts'] ||= {}
      contact = get_contact_name(lines)
      @status['contacts'][contact] ||= {}
      lines.each do |line|
        match = line.match(/^\s*(.+)=(.*)$/)
        @status['contacts'][contact][match[1]] = match[2] unless match[1] == 'contact_name'
      end
    end

    def get_contact_name(lines)
      if h = lines.grep(/\s+contact_name=(\w+)/).first
        if h =~ /contact_name=(.*)$/
          contact_name = Regexp.last_match(1)
        else
          fail("Can't parse contact_name in block: #{h}")
        end
      else
        fail("Can't parse contactstatus block")
      end
      contact_name
    end

    # Parses a servicecomment block
    def handle_servicecomment(lines)
      host = get_host_name(lines)
      service = get_service_name(lines)
      @status["hosts"][host]['servicecomments'] ||= {}
      @status["hosts"][host]['servicecomments'][service] ||= []
      comment = {}
      lines.each do |line|
        match = line.match(/^\s*(.+)=(.*)$/)
        comment[match[1]] = match[2] unless match[1] == 'service_name'
      end
      @status['hosts'][host]['servicecomments'][service] << comment
    end

    # Parses hostcomment block
    def handle_hostcomment(lines)
      host = get_host_name(lines)
      @status['hosts'][host]['hostcomments'] ||= []
      comment = {}
      lines.each do |line|
        match = line.match(/^\s*(.+)=(.*)$/)
        comment[match[1]] = match[2] unless match[1] == 'host_name'
      end
      @status['hosts'][host]['hostcomments'] << comment
    end

    # Parses servicedowntime block
    def handle_servicedowntime(lines)
      host = get_host_name(lines)
      service = get_service_name(lines)
      downtime_id = get_downtime_id(lines)
      @status["hosts"][host]["servicedowntime"] = {} unless @status["hosts"][host]["servicedowntime"]
      @status["hosts"][host]["servicedowntime"][service] = downtime_id
    end

    # Parses hostdowntime block
    def handle_hostdowntime(lines)
      host = get_host_name(lines)
      downtime_id = get_downtime_id(lines)
      @status["hosts"][host]["hostdowntime"] = downtime_id
    end

    # Parse the downtime_id out of a block
    def get_downtime_id(lines)
      if h = lines.grep(/\s+downtime_id=(.*)$/).first
        if h =~ /downtime_id=(.+)$/
          downtime_id = Regexp.last_match(1)
        else
          fail("Can't parse downtime_id in block: #{h}")
        end
      else
        fail("Can't find downtime_id in block")
      end

      downtime_id
    end

    # Parses a programstatus block
    def handle_programstatus(lines)
      @status["process"] = {} unless @status["process"]

      lines.each do |l|
        @status["process"][Regexp.last_match(1)] = Regexp.last_match(2) if l =~ /\s+(\w+)=(\w+)/
      end
    end

    # Parses a hoststatus block
    def handle_hoststatus(lines)
      host = get_host_name(lines)

      @status["hosts"][host] = {} unless @status["hosts"][host]
      @status["hosts"][host]["hoststatus"] = {} unless @status["hosts"][host]["hoststatus"]

      lines.each do |l|
        if l =~ /\s+(\w+)=(.+)\s*$/
          @status["hosts"][host]["hoststatus"][Regexp.last_match(1)] = Regexp.last_match(2)
        end
      end
    end
  end
end

# vi:tabstop=2:expandtab:ai:filetype=ruby
