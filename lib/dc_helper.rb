require "dc_helper/version"

module DcHelper

  #request to device cloud.  takes url, xml formatted request, user name, and password as parameters
  #as well as http type, which is either "get" or "post"
  #sci requests use get, xbee requests use get
  def self.request(cloud_url, command, http_type, user_name, password)
    url = URI.parse(cloud_url)

    #change http method based on type of request
    if http_type == "post"
      req = Net::HTTP::Post.new(url.path)
    elsif http_type == "get"
      req = Net::HTTP::Get.new(url.path)
    end

    # Sets The Request up for Basic Authentication.
    # Replace YourUsername and YourPassword with your username and password respectively.
    req.basic_auth user_name, password
    # Injects XML Content into Request Body.
    req.body = command

    # Informs Server that the input is in XML format.
    req.set_content_type('text/xml')

    # Create an HTTP connection and send data to capture response.
    res = Net::HTTP.new(url.host, url.port) #.start {|http| http.request(req) }

    #increased timeout period - device cloud sometimes takes longer than default timeout
    res.read_timeout = 70
    res = res.start {|http| http.request(req) }

    # Print an Error if the response was not completely successful.
    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
    else
      "Communication failed."
    end

    #return request result
    return res.body
  end
  #check if device responds to an xbee NI command
  #returns boolean based on whether a proper response was received
  def self.device_online?(mac)
    command ='<sci_request version="1.0">
      <send_message>
        <targets>
          <device id="all"/>
        </targets>
        <rci_request version="1.1">
          <do_command target="xig">
            <at hw_address="' << mac << '!" command="NI" />
          </do_command>
        </rci_request>
      </send_message>
      </sci_request>'

    #make request and get returned values
    result = request(@sci_url, command, "post")

    #downcase for easy comparison
    result = result.downcase
    station = station_name.downcase

    #return boolean value, true if station is online, false if offline
    if result.include? station
      true
    else
      false
    end
  end


  #function to change station id.  takes the station's mac address and the new name as parameters
  def self.change_id(mac, new_name)
    command ='<sci_request version="1.0">
      <send_message>
        <targets>
          <device id="all"/>
        </targets>
        <rci_request version="1.1">
          <do_command target="zigbee">
            <set_setting addr="'<< mac <<'!">
          <radio>
          <node_id>' << new_name << '</node_id>
          </radio>
      </set_setting>
          </do_command>
        </rci_request>
      </send_message>
    </sci_request>'

    #make request and get returned values
    result = request(@sci_url, command, "post")

    #return confirmation message
    return "station name change submitted"
  end


  #returns a hash of station names (key) and their mac addresses(value)
  def self.find_all_nodes(clear = false)
    if clear
      #make request and get results
      result = request(@xbee_core_url,"&clear=true","get")
    else
      #make request and get results
      result = request(@xbee_core_url,'',"get")
    end

    #load with nokogiri and prepare to parse through the xbee nodes
    xml = Nokogiri::XML(result)
    xbees = xml.xpath("//XbeeCore")

    #hash that will be returned with station names and their ids
    node_results = Hash.new(0)
    #check each node
    #if node is a gateway, don't include in results
    xbees.each do |xbee|
      #get the values from the xml elements
      mac = xbee.search 'xpExtAddr'
      mac = mac.inner_text
      name = xbee.search 'xpNodeId'
      name = name.inner_text
      device_type = xbee.search 'xpDeviceType'
      device_type = device_type.inner_text

      #check if node is a gateway
      if device_type == "327683" || device_type == "720899"
        #don't include the gateway, but add gateway to database if it doesn't already exist
        #binding.pry
        gateway_id = xbee.search 'devConnectwareId'
        gateway_id = gateway_id.inner_text
        add_gateway(name, gateway_id)
      else
        #add name and mac to hash
        node_results[name] = mac
      end
    end
    #return nodes
    node_results
  end

  #config settings segment ****************
  # Configuration defaults
  @config = {
  	#Device Cloud credentials
    :login => "temp",
    :password => "temp",
    #Device Cloud urls
    :sci_url => "",
    :xbee_core_url => ""
  }

  @valid_config_keys = @config.keys

  # Configure through hash
  def self.configure(opts = {})
    opts.each {|k,v| @config[k.to_sym] = v if @valid_config_keys.include? k.to_sym}

    puts "Device Cloud account information configured"
    puts "user name: " << @config.login
    puts "password: " << @config.password

  end

  # # Configure through yaml file
  # def self.configure_with(path_to_yaml_file)
  #   begin
  #     config = YAML::load(IO.read(path_to_yaml_file))
  #   rescue Errno::ENOENT
  #     log(:warning, "YAML configuration file not found. Using defaults."); return
  #   rescue Psych::SyntaxError
  #     log(:warning, "YAML configuration file contains invalid syntax. Using defaults."); return
  #   end

  #   configure(config)
  # end

  def self.config
    @config
  end
  # END config settings segment ****************

end

