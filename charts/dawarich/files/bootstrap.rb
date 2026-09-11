# SPDX-License-Identifier: Apache-2.0
require 'digest'
identity_keys = %w[SECRET_KEY_BASE OTP_ENCRYPTION_PRIMARY_KEY OTP_ENCRYPTION_DETERMINISTIC_KEY OTP_ENCRYPTION_KEY_DERIVATION_SALT]
fingerprint = Digest::SHA256.hexdigest(identity_keys.map { |name| ENV.fetch(name) }.join("\0"))
marker = '/workspace/.identity-fingerprint'
if User.unscoped.exists?
  raise 'Existing user database requires retained identity fingerprint' unless File.exist?(marker)
  raise 'Identity keys changed; use a reviewed native rotation procedure' unless File.read(marker) == fingerprint
  raise 'Existing database has no active administrator' unless User.where(admin: true, status: :active).exists?
  puts 'Existing native identity preserved; first administrator not recreated'
else
  raise 'Identity marker exists with an empty user database; recovery review required' if File.exist?(marker)
  password = File.read('/bootstrap-auth/password')
  raise 'Administrator password requires at least 16 characters and at most 72 UTF-8 bytes' if password.length < 16 || password.bytesize > 72
  user = User.create!(email: ENV.fetch('BOOTSTRAP_EMAIL'), password: password, password_confirmation: password,
    admin: true, status: :active, active_until: 100.years.from_now)
  raise 'Native administrator or API key was not created' unless user.admin? && user.api_key.present?
  File.write(marker, fingerprint, mode: 'wx', perm: 0o600)
  puts 'Native administrator provisioned before seeds without opening an HTTP listener'
end
raise 'Unsafe default seed identity requires explicit removal or review' if User.unscoped.find_by(email: 'demo@dawarich.app')&.valid_password?('safepassword')
DawarichSettings.set_registration_enabled(false)
