# SPDX-License-Identifier: Apache-2.0
require 'pg'
require 'redis'
require 'uri'
require 'socket'

def rejected(label)
  begin
    yield
  rescue StandardError => error
    raise "#{label} did not fail as a certificate verification error" unless error.message.match?(/certificate|verify|ssl|hostname/i)
    return
  end
  raise "#{label} unexpectedly accepted an invalid certificate"
end

if ENV['PGSSLMODE'] == 'verify-full'
  options = {host: ENV.fetch('DATABASE_HOST'), port: ENV.fetch('DATABASE_PORT'), dbname: ENV.fetch('DATABASE_NAME'),
    user: ENV.fetch('DATABASE_USERNAME'), password: ENV.fetch('DATABASE_PASSWORD'), connect_timeout: 5}
  connection = PG.connect(**options)
  raise 'PostGIS connection is not encrypted' unless connection.exec('SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid()').getvalue(0, 0) == 't'
  raise 'PostGIS extension missing' unless connection.exec('SELECT PostGIS_Version()').getvalue(0, 0).start_with?('3.')
  connection.close
  rejected('PostGIS unknown CA') { PG.connect(**options, sslrootcert: '/etc/ssl/certs/ca-certificates.crt').close }
  address = IPSocket.getaddress(ENV.fetch('DATABASE_HOST'))
  rejected('PostGIS wrong hostname') { PG.connect(**options, host: 'wrong-certificate.example.test', hostaddr: address).close }
  puts 'PASS libpq verify-full: actual encrypted PostGIS session; unknown CA and wrong hostname rejected'
end

if ENV['HF_REDIS_TLS'] == 'true'
  credentials = [ENV.fetch('HF_REDIS_USERNAME', ''), ENV.fetch('HF_REDIS_PASSWORD')].map { |value| URI.encode_www_form_component(value).gsub('+', '%20') }.join(':')
  build_url = ->(host) { URI::Generic.build(scheme: 'rediss', userinfo: credentials, host: host, port: Integer(ENV.fetch('HF_REDIS_PORT')), path: '/0').to_s }
  url = build_url.call(ENV.fetch('HF_REDIS_HOST'))
  redis = Redis.new(url: url, timeout: 5)
  raise 'Authenticated TLS Redis PING failed' unless redis.ping == 'PONG'
  redis.close
  rejected('Redis wrong hostname') do
    client = Redis.new(url: build_url.call(IPSocket.getaddress(ENV.fetch('HF_REDIS_HOST'))), timeout: 5)
    begin; client.ping; ensure; client.close; end
  end
  ENV['SSL_CERT_FILE'] = '/etc/ssl/certs/ca-certificates.crt'
  rejected('Redis unknown CA') do
    client = Redis.new(url: url, ssl_params: {ca_file: ENV.fetch('SSL_CERT_FILE')}, timeout: 5)
    begin; client.ping; ensure; client.close; end
  end
  puts 'PASS native Redis TLS: authenticated PING; unknown CA and wrong hostname rejected'
end

if ENV['STORAGE_BACKEND'] == 's3'
  require 'aws-sdk-s3'
  require 'net/http'
  require 'digest'
  endpoint = ENV.fetch('AWS_ENDPOINT_URL')
  options = {region: ENV.fetch('AWS_REGION'), endpoint: endpoint, retry_limit: 0,
    access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID'), secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY')}
  client = Aws::S3::Client.new(**options)
  bucket = ENV.fetch('AWS_BUCKET')
  client.head_bucket(bucket: bucket)
  if ARGV[0]
    object = client.list_objects_v2(bucket: bucket).contents.find do |item|
      Digest::SHA256.hexdigest(client.get_object(bucket: bucket, key: item.key).body.read) == ARGV[0]
    end
    raise 'Original GPX bytes were not found in the actual S3 bucket' unless object
    target = URI(endpoint)
    target.path = '/' + bucket + '/' + object.key
    http = Net::HTTP.new(target.host, target.port)
    http.use_ssl = true
    http.ca_file = ENV['AWS_CA_BUNDLE'] if ENV['AWS_CA_BUNDLE']
    http.open_timeout = 5
    http.read_timeout = 5
    raise 'Unsigned object read must be denied' unless http.get(target.request_uri).code == '403'
    puts 'PASS exact GPX bytes in the actual S3 bucket and rejected unsigned object read'
  end
  rejected('S3 unknown CA') do
    Aws::S3::Client.new(**options, ssl_ca_bundle: '/etc/ssl/certs/ca-certificates.crt').head_bucket(bucket: ENV.fetch('AWS_BUCKET'))
  end
  uri = URI(endpoint)
  uri.host = IPSocket.getaddress(uri.host)
  rejected('S3 wrong hostname') do
    Aws::S3::Client.new(**options, endpoint: uri.to_s).head_bucket(bucket: ENV.fetch('AWS_BUCKET'))
  end
  puts 'PASS native AWS SDK HTTPS: authenticated bucket access; unknown CA and wrong hostname rejected'
end
