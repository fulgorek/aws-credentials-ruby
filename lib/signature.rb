require "uri"
require "time"
require "openssl"

module AWS
  class Signature
    attr_writer :method, :uri, :region, :date, :payload, :service, :headers

    def initialize(access_key, secret_key)
      @access_key, @secret_key = access_key, secret_key
    end

    def method
      @method ||= 'GET'
    end

    def uri
      begin
        @uri.kind_of?(URI) ? @uri : URI.parse(@uri)
      rescue
        puts 'You need to set the uri resource!'
        exit
      end
    end

    def region
      @region ||= 'us-east-1'
    end

    def headers
      @headers ||= default_headers
    end

    def default_headers
      { 'Host' => uri.host }
    end

    def date
      @date ||= Time.now.utc.iso8601.to_s.gsub(/\W/, '')
    end

    def payload
      @payload ||= ''
    end

    def service
      @service ||= uri.host.split('.')[0]
    end

    def auth_header
      "AWS4-HMAC-SHA256 Credential=#{@access_key}/#{credentials}, SignedHeaders=#{signed_headers}, Signature=#{signature}"
    end

    def signature
      kDate    = hmac('AWS4' + @secret_key, short_date)
      kRegion  = hmac(kDate, region)
      kService = hmac(kRegion, service)
      kSigning = hmac(kService, 'aws4_request')
      hexdigest_hmac(kSigning, string_to_sign)
    end

    private

    def short_date
      Time.parse(date).strftime("%Y%m%d")
    end

    def string_to_sign
      ['AWS4-HMAC-SHA256', date, credentials, digest(canonical_request)].join("\n")
    end

    def credentials
      [short_date, region, service, 'aws4_request'].join('/')
    end

    def canonical_request
      [ method,
        uri.path,
        normalized_query_string,
        canonical_headers,
        signed_headers,
        digest(payload)
      ].join("\n")
    end

    def normalized_query_string
      uri.query.split('&').map{|v| [v.split("=")[0], v] }.sort_by{|v| v[0] }.map{|v| [v[1]]}.join('&') if uri.query
    end

    def canonical_headers
      headers.sort_by {|k,v| k.downcase}.map do |k, v|
        v = "" if k == "X-Amz-Date"
        [k.downcase.strip, v.to_s.strip.gsub(/\s+/,' ')].join(':')
      end.join("\n") + "\n"
    end

    def signed_headers
      headers.sort_by{|k, v| k.downcase }.map{|k, v| k.downcase}.join(';')
    end

    def digest(value)
      Digest::SHA256.new.update(value).hexdigest
    end

    def hmac(key, value)
      OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, value)
    end

    def hexdigest_hmac(key, value)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), key, value)
    end
  end
end
