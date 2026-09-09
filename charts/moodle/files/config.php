<?php
// SPDX-License-Identifier: Apache-2.0
unset($CFG);
$CFG = new stdClass();
$settings = json_decode(file_get_contents('/opt/helmforge/settings.json'), true, 512, JSON_THROW_ON_ERROR);
$app = $settings['moodle'];
$CFG->dbtype = 'pgsql';
$CFG->dblibrary = 'native';
$CFG->dbhost = getenv('DB_HOST');
$CFG->dbname = getenv('DB_NAME');
$CFG->dbuser = getenv('DB_USER');
$CFG->dbpass = getenv('DB_PASSWORD');
$CFG->prefix = $settings['database']['prefix'];
$CFG->dboptions = ['dbpersist' => false, 'dbport' => (int)getenv('DB_PORT'), 'dbsocket' => false,
    'ssl' => $settings['database']['sslMode']];
if ($settings['database']['tlsSecret'] !== '') {
    $CFG->dboptions['sslrootcert'] = '/opt/database-tls/ca.crt';
}
$CFG->wwwroot = $app['wwwroot'];
$CFG->dataroot = '/var/moodledata';
$CFG->localcachedir = '/tmp/moodle-localcache';
$CFG->localrequestdir = '/tmp/moodle-requests';
$CFG->directorypermissions = 02770;
$CFG->sslproxy = $app['sslProxy'];
$CFG->reverseproxy = $app['reverseProxy'];
$CFG->cookiesecure = str_starts_with($CFG->wwwroot, 'https://');
$CFG->cookiehttponly = true;
$CFG->disableupdateautodeploy = $app['disableUpdateAutodeploy'];
$CFG->noemailever = $app['noEmailEver'];
$CFG->timezone = $app['timezone'];
$CFG->lock_factory = '\\core\\lock\\postgres_lock_factory';
$CFG->debug = 0;
$CFG->debugdisplay = false;
if ($settings['sessions']['enabled']) {
    $session = $settings['sessions'];
    $CFG->session_handler_class = '\\core\\session\\redis';
    $CFG->session_redis_host = getenv('REDIS_HOST');
    $CFG->session_redis_port = (int)$session['port'];
    $CFG->session_redis_database = (int)$session['database'];
    $CFG->session_redis_prefix = $session['prefix'];
    $CFG->session_redis_auth = getenv('REDIS_PASSWORD') ?: '';
    $CFG->session_redis_acquire_lock_timeout = (int)$session['acquireLockTimeout'];
    $CFG->session_redis_lock_expire = (int)$session['lockExpire'];
    if ($session['tlsSecret'] !== '') {
        $CFG->session_redis_encrypt = ['cafile' => '/opt/redis-tls/ca.crt', 'verify_peer' => true, 'verify_peer_name' => true];
    }
}
if ($settings['smtp']['hosts'] !== '') {
    $CFG->smtphosts = $settings['smtp']['hosts'];
    $CFG->smtpsecure = $settings['smtp']['security'];
    $CFG->smtpuser = $settings['smtp']['username'];
    $CFG->smtppass = getenv('SMTP_PASSWORD') ?: '';
}
$CFG->noreplyaddress = $settings['smtp']['noReplyAddress'];
require '/opt/helmforge/extra-config.php';
if ($settings['metrics']['enabled']) {
    $token = trim(file_get_contents('/opt/metrics-auth/token'));
    if ($token === '') { throw new RuntimeException('Metrics token must not be empty'); }
    $CFG->forced_plugin_settings['monitoringexporter_prometheus']['prometheus_token'] = $token;
    // Prometheus connects to pod IPs on the private listener. Present Moodle's
    // canonical origin internally so its routing does not redirect the scrape.
    // SERVER_PORT is supplied by Apache, not a forwarded client header.
    if (($_SERVER['SERVER_PORT'] ?? '') === '9090') {
        $origin = parse_url($CFG->wwwroot);
        $_SERVER['HTTP_HOST'] = $origin['host'] . (isset($origin['port']) ? ':' . $origin['port'] : '');
        $_SERVER['SERVER_NAME'] = $origin['host'];
        $_SERVER['SERVER_PORT'] = (string)($origin['port'] ?? ($origin['scheme'] === 'https' ? 443 : 80));
        $_SERVER['HTTPS'] = $origin['scheme'] === 'https' ? 'on' : 'off';
        $CFG->reverseproxy = false;
    }
}
require_once(__DIR__ . '/lib/setup.php');
