#!/bin/sh
# Inject the backend URL environment variable into the Nginx config template
envsubst '${BACKEND_URL}' < /etc/nginx/conf.d/nginx.conf.template > /etc/nginx/conf.d/default.conf

# Start Nginx
nginx -g 'daemon off;'