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

        # Returns a list of all hosts, pass an array of service names to restrict the list to
        # hosts with that service
        def find_hosts(options = {})
            withservice = options.fetch(:withservice, [])

            hosts = []

            if withservice.size > 0
                withservice.each do |service|
                    @status["hosts"].each do |host, v|
                        if @status["hosts"][host].has_key?("servicestatus")
                            hosts << host if @status["hosts"][host]["servicestatus"].has_key?(service)
                        end
                    end
                end

            # just give us all hosts
            else
                @status["hosts"].each { |host, v| hosts << host }
            end

            hosts.uniq.sort
        end

        # Returns a list of all services, pass an array of host names to restrict the list to
        # services for those hosts
        def find_services(options = {})
            forhost = options.fetch(:forhost, [])
            notifications = options.fetch(:notifyenabled, nil)
            action = options.fetch(:action, nil)
            withservice = options.fetch(:withservice, [])

            services = []
            searchquery = []

            # Build up a search query for find_service_with_properties 
            # each array member is a hash of property and a match
            if forhost.size > 0
                forhost.each do |host|
                    # Make a regex if the input on host matches "/"
                    host = Regexp.new(host.gsub("\/", "")) if host.match("/")

                    searchquery << {"host_name" => host}
                end
            else
                    searchquery << {"host_name" => /./}
            end

            if withservice.size > 0
                withservice.each do |s|
                    # Make a regex if the input on service matches "/"
                    s = Regexp.new(s.gsub("\/", "")) if s.match("/")

                    searchquery << {"service_description" => s}
                end
            end

            searchquery << {"notifications_enabled" => notifications.to_s} if notifications

            svcs = find_service_with_properties(searchquery)

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
        # Return service blocks for each service that matches any options like:
        #
        # "host_name" => "foo.com"
        #
        # The 2nd parameter can be a regex too.
        def find_service_with_properties(search)
            services = []
            query = []

            query << search if search.class == Hash
            query = search if search.class == Array

            find_hosts.each do |host|
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
