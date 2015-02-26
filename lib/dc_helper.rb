require "dc_helper/version"

module DcHelper

  def self.test
    puts "Initial test"
  end

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
      #Ok
    else
      #"res.error!"
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
    result = request(@@sci_url, command, "post")

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
    result = request(@@sci_url, command, "post")

    #return confirmation message
    return "station name change submitted"
  end
end
