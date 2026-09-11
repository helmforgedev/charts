# SPDX-License-Identifier: Apache-2.0
require 'sidekiq/api'
require 'timeout'

Timeout.timeout(4) do
  Sidekiq.configure_client do |config|
    config.redis = {url: ENV.fetch('REDIS_URL'), db: Integer(ENV.fetch('RAILS_JOB_QUEUE_DB')), network_timeout: 2}
  end
  healthy = Sidekiq::ProcessSet.new(false).any? do |process|
    process['hostname'] == ENV.fetch('HOSTNAME') && process['pid'].to_i == 1 &&
      Time.now.to_f - process['beat'].to_f < 60 && process['quiet'].to_s == 'false'
  end
  raise 'Native Sidekiq heartbeat is absent, stale or quiet' unless healthy
end
