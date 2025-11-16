# # Use the official lightweight Nginx image
# FROM nginx:alpine

# # Copy the static content (HTML, CSS, JS) into the Nginx server directory
# COPY . /usr/share/nginx/html

# # Copy our custom Nginx configuration
# COPY nginx.conf /etc/nginx/conf.d/default.conf

# # Expose port 80
# EXPOSE 80

FROM nginx:alpine

# Install the tool needed for environment variable substitution
RUN apk add --no-cache gettext

# Copy your static website files
COPY . /usr/share/nginx/html

# Copy the Nginx config template and the startup script
COPY nginx.conf.template /etc/nginx/conf.d/nginx.conf.template
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

EXPOSE 80

# Run the startup script when the container starts
CMD ["/startup.sh"]