#!/usr/bin/env ruby
require 'rubygems'
require 'bundler'
require 'sinatra'
require 'sinatra/base'
require 'sinatra/namespace'
require 'sinatra/json'

require 'base64'
require 'json'
require 'zlib'
require 'stringio'

require 'influxdb'

use Rack::Deflater
Response = Struct.new(:body) do
  def initialize(*)
    super
    self.body ||= {return_value:  []}
  end
end

namespace '/agent_listener' do
  # API v16
  post '/invoke_raw_method' do
    method = params['method']
    response = case method
    when 'preconnect'              
      Response.new( { return_value:  { redirect_host: request.host }} )
    when 'connect'                 
      Response.new( { return_value:  { agent_run_id: 1 }} )
    when 'get_agent_commands'
      Response.new
    when 'agent_command_results'
      Response.new
    when 'metric_data'
      request.body.rewind
      body = request.body.read
      body = Zlib::Inflate.inflate(body) if request.env["HTTP_CONTENT_ENCODING"] == "deflate"
      metrics = JSON.parse body
      data = []
      metrics[3].each do |meta, values|
        data << {
          series: 'metric_data',
          tags: { metric_name: meta['name'] },
          values: {
            cnt: values[0],
            val: values[1],
            own: values[2],
            min: values[3],
            max: values[4],
            sqr: values[5]
          }
        }
        # single_to_influx('metric_data', data)
      end
      to_influx(data)
      Response.new
    when 'sql_trace_data'
      request.body.rewind
      p request.env
      Response.new
    when 'transaction_sample_data'
      request.body.rewind
      p request.env
      Response.new
    when 'error_data'
      request.body.rewind
      p request.env
      Response.new
    when 'profile_data'
      request.body.rewind
      p request.body.to_s
      Response.new
    when 'shutdown'
      Response.new
    when 'analytic_event_data'
      request.body.rewind
      # p request.body
      body = request.body.read
      puts body
      body = Zlib::Inflate.inflate(body) if request.env["HTTP_CONTENT_ENCODING"] == "deflate"
      json_analytics = JSON.parse body
      # loop over events
      # [1, {reservoir, events seen}, [events] ]
      if json_analytics.length == 3
        data = []
        json_analytics[2].each do |meta, _wtf|
          p meta
          next unless meta['name']
          data << {
            series: 'analytics_data',
            tags: { 
              metric_ts: meta['timestamp'],
              metric_name: meta['name'],
              mtype: meta['type'] 
            },
            values: { 
              mduration: meta['duration'] || 0.0, 
              mdatabase_duration: meta['databaseDuration'] || 0.0, 
              mdatabase_call_count: meta['databaseCallCount'] ||0
            },
          }
        end
        to_influx(data)
      end
      Response.new
    when 'custom_event_data'
      request.body.rewind
      # p request.env
      Response.new
    when 'error_event_data'
      request.body.rewind
      # p request.env
      Response.new
    when 'span_event_data'
      request.body.rewind
      # p request.env
      Response.new
    end
    json response.body
  end
end

def unblob(blob)
  return unless blob
  JSON.load(Zlib::Inflate.inflate(Base64.decode64(blob)))
end

def to_influx(data)
  begin
    influxdb.write_points(data)
  rescue StandardError => e
    p "----------"
    p data
    p "----------"
    raise e
  end
end

def single_to_influx(name, data)
  begin
    influxdb.write_point(name, data)
  rescue StandardError => e
    p "----------"
    p data
    p "----------"
    raise e
  end
end

def influxdb
  @influxdb ||= InfluxDB::Client.new 'collector', host: ENV['INFLUXDB_HOST']
end
