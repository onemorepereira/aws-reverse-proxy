#!/bin/bash
yum update -y
yum install -y haproxy rsyslog logrotate

# Configure rsyslog to accept UDP logs from localhost (correct for Amazon Linux 2)
cat <<EOF > /etc/rsyslog.d/49-haproxy.conf
module(load="imudp")
input(type="imudp" port="514")
local2.*    /var/log/haproxy.log
EOF


# Restart rsyslog to pick up the new config
systemctl enable rsyslog
systemctl restart rsyslog

# Configure HAProxy with logging and TCP passthrough
cat <<EOF > /etc/haproxy/haproxy.cfg
global
    log 127.0.0.1 local2
    maxconn 2048
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    timeout connect 10s
    timeout client  60s
    timeout server  1m

frontend tls_in
    bind *:443
    default_backend remote_tls

frontend healthcheck
    bind *:9000
    mode tcp
    tcp-request inspect-delay 5s
    tcp-request content accept if { src ${vpc_cidr} }

backend remote_tls
    server upstream1 ${upstream_ip}:${upstream_port} check

backend healthcheck-backend
    mode tcp
    server dummy 127.0.0.1:9000
EOF

# Enable and start HAProxy
systemctl enable haproxy
systemctl restart haproxy

# Set up daily log rotation
cat <<EOF > /etc/logrotate.d/haproxy
/var/log/haproxy.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    delaycompress
    postrotate
        /bin/kill -HUP \$(pidof rsyslogd)
    endscript
}
EOF
