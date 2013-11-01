#!/usr/bin/env ruby -w

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'json'
require 'net/http'
require 'openssl'
require 'pp'

class ZedStats < Sensu::Plugin::Metric::CLI::Graphite

  option :host,
    :short => "-H HOST",
    :long => "--host HOST",
    :description => "HOST to get zstats from",
    :default => "localhost"

  option :port,
    :short => "-p PORT",
    :long => "--port PORT",
    :description => "Port to connect to",
    :default => "8080"

  option :path,
    :short => "-P PATH",
    :long => "--path PATH",
    :description => "PATH to check zstat output",
    :default => "#{Socket.gethostname}/zstats"

  option :user,
    :short => "-user USER",
    :long => "--user USER",
    :description => "User if HTTP Basic is used",
    :default => nil

  option :password,
    :short => "-password USER",
    :long => "--password USER",
    :description => "Password if HTTP Basic is used",
    :default => nil

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "stats.#{Socket.gethostname}"

  option :ssl,
    :short => "-s",
    :boolean => true,
    :description => "Use ssl when connecting",
    :default => false

  option :header,
    :long => "--header value",
    :description => "Addition header to include in request",
    :default => nil

  option :header_value,
    :short => "-v value",
    :long => "--header_value value",
    :description => "The value of the addition header",
    :default => nil

  option :debug,
    :short => "-d",
    :boolean => true,
    :description => "Debug mode",
    :default => false

  option :help,
    :long => "--help",
    :short => "-h",
    :description => "Show this message",
    :on => :tail,
    :show_options => true,
    :boolean => true,
    :exit => 0

  def run
    timestamp = Time.now.to_i
    stats = {}

    value = JSON.parse getJsonfromApi
    value.each do |k,v|
      stats[k] = v
    end
    apiMetrics = {
      :zstat=> stats
    }
    apiMetrics.each do |parent, children|
      children.each do |child, grandchild|
        grandchild.each do |grandchild, value|
          output [config[:scheme], parent, child, grandchild].join("."), value, timestamp
        end
      end
    end
    ok
  end

  def getJsonfromApi
    headerValue = config[:header_value]
    password = config[:password]
    header = config[:header]
    debug = config[:debug]
    port = config[:port]
    path = config[:path]
    user = config[:user]
    host = config[:host]
    ssl = config[:ssl]

    http = Net::HTTP.new(host, port)
    req = Net::HTTP::Get.new(path)
    req.add_field 'User-Agent', 'Sensu-Monitoring-Plugin'

    if ssl == true
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    if debug == true
      http.set_debug_output($stdout)
    end
    if (user != nil and password != nil)
      req.basic_auth user, password
    end
    if (header != nil and headerValue != nil)
      req.add_field header, headerValue
    end

    res = http.request(req) # make the connection

    case res.code
    when "200"
      res.body
    else
      critical message("Error: #{res.code} recieved from #{host}.")
    end
  end
end # end of class
