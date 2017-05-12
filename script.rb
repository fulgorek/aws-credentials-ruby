#!/usr/bin/env ruby

require_relative "lib/signature"
require "net/https"
require "libxml_to_hash"
require "uri"
require "json"
require "parallel"

module AWS
  class Request
    attr_reader :access_key, :secret_key

    ENDPOINTS = {
      :identity   => 'https://sts.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15',
      :list_users => 'https://iam.amazonaws.com/?Action=ListUsers&Version=2010-05-08',
      :access_key => 'https://iam.amazonaws.com/?Action=ListAccessKeys&UserName=%s&Version=2010-05-08'
    }

    MAX_PROCESSES = 64

    def initialize
      verify_gems
      credentials
      parameters
      read_identity
      puts Hash[ list_access_keys.map{ |a| [a.first, a.last] } ].to_json
    end

    private

    def credentials
      if ENV['AWS_ACCESS_KEY'] and ENV['AWS_SECRET_KEY']
        @access_key, @secret_key = ENV['AWS_ACCESS_KEY'], ENV['AWS_SECRET_KEY']
      else
        @access_key = prompt "Enter your Access Key: "
        @secret_key = prompt "Enter your Secret Key: "
        if access_key.empty? || secret_key.empty?
          puts 'Please provide valid credentials, Aborting.'
          exit
        end
      end
    end

    def prompt(*args)
      print(*args)
      gets.rstrip
    end

    def parameters
      params = {}
      ARGV.each do |arg|
        match = /--(?<key>.*?)=(?<value>.*)/.match(arg)
        params[match[:key]] = match[:value]
      end
      params
    end

    def read_identity
      identity = send_request(ENDPOINTS[:identity])
      if identity['ErrorResponse']
        puts 'Invalid AWS profile. Aborting.'
        exit
      end
      identity
    end

    def in_parallel
      parameters['mode'] != 'sync' && Object.const_defined?('Parallel')
    end

    def progress
      parameters['debug'] == 'true' ? "Getting Keys (#{processes} processes)" : nil
    end

    def processes
      procs = parameters['procs'].to_i
      (1..MAX_PROCESSES) === procs ? procs : MAX_PROCESSES
    end

    def list_access_keys
      return list_users.map{ |user| process_keys(user) } unless in_parallel
      Parallel.map(list_users, in_processes: processes, progress: progress) do |user|
        process_keys(user)
      end
    end

    def process_keys(user)
      [user, process_user_keys(send_request(uri_user(user)))]
    end

    def list_users
      @list_users ||= process_users_list
    end

    def process_user_keys(data)
      data = data['ListAccessKeysResponse']['ListAccessKeysResult']['AccessKeyMetadata']['member']
      return [] if data.nil?
      data.is_a?(Array) ? data.map{|x| x['AccessKeyId']} : [data['AccessKeyId']]
    end

    def verify_gems
      if !Hash.methods.include? :from_libxml
        puts 'Please bundle or install `libxml_to_hash` gem first, Aborting!'
        exit
      end
    end

    def signed_request(uri)
      auth     = AWS::Signature.new(access_key, secret_key)
      auth.uri = uri
      [auth.auth_header, auth.date]
    end

    def process_users_list
      list = send_request(ENDPOINTS[:list_users])
      list['ListUsersResponse']['ListUsersResult']['Users']['member'].map{|x| x['UserName']}
    end

    def uri_user(user)
      user = URI.escape(user, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      sprintf(ENDPOINTS[:access_key], user)
    end

    def send_request(endpoint)
      signature    = signed_request(endpoint)
      uri          = URI(endpoint)
      http         = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req          =  Net::HTTP::Get.new(uri)
      req.add_field "Date", signature[1]
      req.add_field "Authorization", signature[0]
      response = http.request(req)
      Hash.from_libxml(response.body)
    rescue StandardError => e
      puts "HTTP Request failed (#{e.message})"
      exit
    end
  end
end

#Run Baby!
AWS::Request.new
