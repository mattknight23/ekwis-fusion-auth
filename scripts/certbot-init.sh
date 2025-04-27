#!/bin/bash
set -e

DOMAIN="auth.ekwis.com"
EMAIL="matt@ekwis.com"  # Change if needed
WEBROOT="/var/www/certbot"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"

# Create webroot for certbot
mkdir -p $WEBROOT

# If certs don't exist, obtain them
if [ ! -f "$CERT_PATH" ]; then
  echo "Obtaining Let's Encrypt certificate for $DOMAIN..."
  certbot certonly --webroot -w $WEBROOT -d $DOMAIN --email $EMAIL --agree-tos --non-interactive
fi

# Start cron for renewal
service cron start || true
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --webroot -w $WEBROOT --quiet && nginx -s reload") | crontab -

# Start NGINX in foreground
nginx -g 'daemon off;' 