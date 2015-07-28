class TransmissionApi::Client
  attr_accessor :session_id
  attr_accessor :url
  attr_accessor :basic_auth
  attr_accessor :fields
  attr_accessor :debug_mode

  TORRENT_FIELDS = [
    "id",
    "name",
    "totalSize",
    "addedDate",
    "isFinished",
    "rateDownload",
    "rateUpload",
    "percentDone",
    "files"
  ]

  def initialize(opts)
    @url = opts[:url]
    @fields = opts[:fields] || TORRENT_FIELDS
    @basic_auth = { :username => opts[:username], :password => opts[:password] } if opts[:username]
    @session_id = "NOT-INITIALIZED"
    @debug_mode = opts[:debug_mode] || false
  end

  def all(opts = {})
    log "get_torrents"

    fields = opts.fetch(:fields) { self.fields }

    get_torrents(fields: fields)
  end

  def find(id, opts = {})
    log "get_torrent: #{id}"

    fields = opts.fetch(:fields) { self.fields }

    get_torrents(:fields => fields,
                 :ids => [id]).first
  end


  def get_torrents(arguments)
    log "get_torrents"

    post_params = { :method => "torrent-get", arguments: arguments }

    response = post(post_params)

    response["arguments"]["torrents"]
  end

  def create(filename)
    log "add_torrent: #{filename}"

    response =
      post(
        :method => "torrent-add",
        :arguments => {
          :filename => filename
        }
      )

    response["arguments"]["torrent-added"]
  end

  def destroy(id)
    log "remove_torrent: #{id}"

    response =
      post(
        :method => "torrent-remove",
        :arguments => {
          :ids => [id],
                       :"delete-local-data" => true
        }
      )

    response
  end

  def post(opts)
    response_parsed = JSON::parse( http_post(opts).body )

    if response_parsed["result"] != "success"
      raise TransmissionApi::Exception, response_parsed["result"]
    end

    response_parsed
  end

  def http_post(opts)
    post_options = {
      :body => opts.to_json,
      :headers => { "x-transmission-session-id" => session_id }
    }
    post_options.merge!( :basic_auth => basic_auth ) if basic_auth

    log "url: #{url}"
    log "post_body:"
    log JSON.parse(post_options[:body]).to_yaml
    log "------------------"

    response = HTTParty.post( url, post_options )

    log_response response

    # retry connection if session_id incorrect
    if( response.code == 409 )
      log "changing session_id"
      @session_id = response.headers["x-transmission-session-id"]
      response = http_post(opts)
    end

    response
  end

  def log(message)
    Kernel.puts "[TransmissionApi #{Time.now.strftime( "%F %T" )}] #{message}" if debug_mode
  end

  def log_response(response)
    body = nil
    begin
      body = JSON.parse(response.body).to_yaml
    rescue
      body = response.body
    end

    headers = response.headers.to_yaml

    log "response.code: #{response.code}"
    log "response.message: #{response.message}"

    log "response.body_raw:"
    log response.body
    log "-----------------"

    log "response.body:"
    log body
    log "-----------------"

    log "response.headers:"
    log headers
    log "------------------"
  end
end
