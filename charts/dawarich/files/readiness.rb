# SPDX-License-Identifier: Apache-2.0
require 'pg'
require 'redis'
require 'uri'
require 'timeout'
require 'net/http'
require 'json'

Timeout.timeout(4) do
  connection = PG.connect(host: ENV.fetch('DATABASE_HOST'), port: ENV.fetch('DATABASE_PORT'),
    dbname: ENV.fetch('DATABASE_NAME'), user: ENV.fetch('DATABASE_USERNAME'),
    password: ENV.fetch('DATABASE_PASSWORD'), connect_timeout: 2)
  begin
    raise 'Database readiness failed' unless connection.exec('SELECT 1').getvalue(0, 0) == '1'
  ensure
    connection.close
  end
  credentials = [ENV.fetch('HF_REDIS_USERNAME', ''), ENV.fetch('HF_REDIS_PASSWORD')].map do |value|
    URI.encode_www_form_component(value).gsub('+', '%20')
  end
  url = URI::Generic.build(scheme: ENV['HF_REDIS_TLS'] == 'true' ? 'rediss' : 'redis',
    userinfo: credentials.join(':'), host: ENV.fetch('HF_REDIS_HOST'),
    port: Integer(ENV.fetch('HF_REDIS_PORT')), path: '/0').to_s
  redis = Redis.new(url: url, db: Integer(ENV.fetch('RAILS_CACHE_DB')), timeout: 2)
  begin
    raise 'Redis readiness failed' unless redis.ping == 'PONG'
  ensure
    redis.close
  end
  request = Net::HTTP::Get.new('/api/v1/health')
  request['Host'] = ENV.fetch('APPLICATION_HOSTS')
  request['X-Forwarded-Proto'] = ENV.fetch('APPLICATION_PROTOCOL')
  response = Net::HTTP.start('127.0.0.1', 3010, open_timeout: 2, read_timeout: 2) { |http| http.request(request) }
  raise 'Native HTTP readiness failed' unless response.code == '200' && JSON.parse(response.body)['status'] == 'ok'
end
