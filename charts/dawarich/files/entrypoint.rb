# SPDX-License-Identifier: Apache-2.0
require 'fileutils'
require 'uri'
require 'digest'
require 'timeout'

File.umask(0o077)
if ARGV.fetch(0) == 'prepare'
  FileUtils.mkdir_p('/tmp/dawarich', mode: 0o700)
  File.chmod(0o700, '/tmp/dawarich')
  %w[storage public imports].each { |name| FileUtils.mkdir_p('/workspace/' + name) }
  FileUtils.rm_rf('/workspace/public/assets')
  Dir.children('/var/app/public_dist').each { |name| FileUtils.cp_r('/var/app/public_dist/' + name, '/workspace/public/') }
  puts 'Prepared native assets and durable storage paths without changing image files'
  exit
end

ENV.delete('BUNDLE_PATH')
ENV.delete('BUNDLE_BIN')
redis_credentials =
  URI.encode_www_form_component(ENV.fetch('HF_REDIS_USERNAME', '')).gsub('+', '%20') + ':' +
  URI.encode_www_form_component(ENV.fetch('HF_REDIS_PASSWORD')).gsub('+', '%20')
ENV['REDIS_URL'] = URI::Generic.build(scheme: ENV['HF_REDIS_TLS'] == 'true' ? 'rediss' : 'redis',
  userinfo: redis_credentials, host: ENV.fetch('HF_REDIS_HOST'), port: Integer(ENV.fetch('HF_REDIS_PORT')), path: '/0').to_s
Dir.chdir('/var/app')

case ARGV.fetch(0)
when 'bootstrap'
  if ENV['HF_REDIS_CA']
    bundle = File.binread('/etc/ssl/certs/ca-certificates.crt') + "\n" + File.binread(ENV.fetch('HF_REDIS_CA'))
    File.write('/tmp/helmforge-ca-bundle.pem', bundle, perm: 0o600)
  end
  require 'pg'
  require 'redis'
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 90
  loop do
    begin
      connection = PG.connect(host: ENV.fetch('DATABASE_HOST'), port: ENV.fetch('DATABASE_PORT'),
        dbname: ENV.fetch('DATABASE_NAME'), user: ENV.fetch('DATABASE_USERNAME'), password: ENV.fetch('DATABASE_PASSWORD'), connect_timeout: 5)
      extensions = connection.exec("SELECT extname FROM pg_extension WHERE extname IN ('postgis','pgcrypto')").map { |row| row['extname'] }
      raise 'PostGIS and pgcrypto must be installed by the DBA' unless extensions.sort == %w[pgcrypto postgis]
      if connection.exec("SELECT to_regclass('public.users') IS NOT NULL AS present").getvalue(0, 0) == 't' &&
         connection.exec('SELECT EXISTS (SELECT 1 FROM users)').getvalue(0, 0) == 't'
        keys = %w[SECRET_KEY_BASE OTP_ENCRYPTION_PRIMARY_KEY OTP_ENCRYPTION_DETERMINISTIC_KEY OTP_ENCRYPTION_KEY_DERIVATION_SALT]
        fingerprint = Digest::SHA256.hexdigest(keys.map { |name| ENV.fetch(name) }.join("\0"))
        marker = '/workspace/.identity-fingerprint'
        raise 'Existing users require the retained identity fingerprint before migrations' unless File.file?(marker) && File.read(marker) == fingerprint
      end
      if connection.exec("SELECT to_regclass('public.imports') IS NOT NULL AS present").getvalue(0, 0) == 't'
        legacy = connection.exec("SELECT EXISTS (SELECT 1 FROM imports) AND NOT EXISTS (SELECT 1 FROM schema_migrations WHERE version = '20260125100000') AS pending").getvalue(0, 0)
        raise 'Existing imports require review of native transportation backfill migration 20260125100000 before upgrade' if legacy == 't'
      end
      connection.close
      [ENV.fetch('RAILS_CACHE_DB'), ENV.fetch('RAILS_JOB_QUEUE_DB')].each do |db|
        redis = Redis.new(url: ENV.fetch('REDIS_URL'), db: Integer(db), timeout: 5)
        begin
          raise 'Redis authentication failed' unless redis.ping == 'PONG'
        ensure
          redis.close
        end
      end
      break
    rescue PG::ConnectionBad, Redis::BaseConnectionError
      raise 'PostGIS or Redis admission timed out' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 2
    end
  end
  [['bundle', 'exec', 'rails', 'db:migrate'], ['bundle', 'exec', 'rake', 'data:migrate'],
   ['bundle', 'exec', 'rails', 'runner', '/helmforge/bootstrap.rb'], ['bundle', 'exec', 'rails', 'db:seed']].each do |command|
    raise 'Native migration/bootstrap/seed command failed' unless system(*command)
  end
  puts 'Native schema, data, private administrator and seed sequence completed'
when 'web'
  FileUtils.rm_f('/var/app/tmp/pids/server.pid')
  exec('bundle', 'exec', 'bin/rails', 'server', '-p', '3010', '-b', '127.0.0.1')
when 'worker'
  exec('bundle', 'exec', 'sidekiq')
when 'runner'
  exec('bundle', 'exec', 'rails', 'runner', ARGV.fetch(1))
when 'worker-health'
  exec('bundle', 'exec', 'ruby', '/helmforge/worker-health.rb')
else
  raise 'Unknown runtime command'
end
