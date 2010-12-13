module Nagios
    class Status
        attr_reader :status

        # Parses a nagios status file returning a data structure for all the data
        def parsestatus(statusfile)
                @status = {}
                @status["hosts"] = {}

                handler = ""
                blocklines = []

                File.readlines(statusfile).each do |line|
                    # start of new sections
                    if line =~ /(\w+) \{/
                        blocklines = []
                        handler = $1
                    end

                    # gather all the lines for the block into an array
                    # we'll pass them to a handler for this kind of block
                    if line =~ /\s+(\w+)=(.+)/ && handler != ""
                        blocklines << line
                    end

                    # end of a section
                    if line =~ /\}/ && handler != ""
                        eval("handle_#{handler}(blocklines)")
                        handler = ""
                    end
                end
        end

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

            searchquery << {"notifications_enabled" => notifications.to_s} if notifications

            svcs = find_with_properties(searchquery)

            svcs.each do |service|
                service_description = service["service_description"]
                host_name = service["host_name"]

                # when printing services with notifications en/dis it makes
                # most sense to print them in host:service format, abuse the
                # action option to get this result
                action = "${host}:${service}" if (notifications != nil && action == nil)

                services << parse_command_template(action, host_name, service_description, service_description)
            end

            services.uniq.sort
        end

        private

        # Add search terms, does all the mangling of regex vs string and so on
        def search_term(haystack, needle)
            needle = Regexp.new(needle.gsub("\/", "")) if needle.match("^/")
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

            @status["hosts"].each do |host,v|
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

                    if matchcount == query.size
                        services << service
                    end
                end
            end

            services
        end

        # yields the hash for each service on a host
        def find_host_services(host)
            if @status["hosts"][host].has_key?("servicestatus")
                @status["hosts"][host]["servicestatus"].each do |s, v|
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
            if s = lines.grep(/\s+service_description=(\w+)/).first
                if s =~ /service_description=(.+)$/
                    service = $1
                else
                    raise("Cant't parse service in block: #{s}")
                end
            else
                raise("Cant't find a hostname in block")
            end

            service
        end

        # Figures out the host name from a block in a nagios status file
        def get_host_name(lines)
            if h = lines.grep(/\s+host_name=(\w+)/).first
                if h =~ /host_name=(.+)$/
                    host = $1
                else
                    raise("Cant't parse hostname in block: #{h}")
                end
            else
                raise("Cant't find a hostname in block")
            end

            host
        end

        # Parses an info block
        def handle_info(lines)
            @status["info"] = {} unless @status["info"]

            lines.each do |l|
                if l =~ /\s+(\w+)=(\w+)/
                    @status["info"][$1] = $2
                end
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
                    if $1 == "host_name"
                        @status["hosts"][host]["servicestatus"][service][$1] = host
                    else
                        @status["hosts"][host]["servicestatus"][service][$1] = $2
                    end
                end
            end
        end

        # Parses a servicestatus block
        def handle_contactstatus(lines)
        end

        # Parses a servicecomment block
        def handle_servicecomment(lines)
        end

        # Parses hostcomment block
        def handle_hostcomment(lines)
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
              downtime_id = $1
            else
              raise("Can't parse downtime_id in block: #{h}")
            end
          else
            raise("Can't find downtime_id in block")
          end
          
          return downtime_id
        end
        
        # Parses a programstatus block
        def handle_programstatus(lines)
            @status["process"] = {} unless @status["process"]

            lines.each do |l|
                if l =~ /\s+(\w+)=(\w+)/
                    @status["process"][$1] = $2
                end
            end
        end

        # Parses a hoststatus block
        def handle_hoststatus(lines)
            host = get_host_name(lines)

            @status["hosts"][host] = {} unless @status["hosts"][host]
            @status["hosts"][host]["hoststatus"] = {} unless @status["hosts"][host]["hoststatus"]

            lines.each do |l|
                if l =~ /\s+(\w+)=(\w+)/
                    @status["hosts"][host]["hoststatus"][$1] = $2
                end
            end
        end
    end
end

# vi:tabstop=4:expandtab:ai:filetype=ruby
