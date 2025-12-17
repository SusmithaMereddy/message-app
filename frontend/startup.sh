#!/bin/sh
set -e

echo "Starting frontend with BACKEND_URL=$BACKEND_URL"

# Replace $BACKEND_URL in the Nginx template
envsubst '$BACKEND_URL' < /etc/nginx/conf.d/nginx.conf.template > /etc/nginx/conf.d/default.conf

# Start Nginx
nginx -g 'daemon off;'
