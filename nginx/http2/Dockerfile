FROM nginx:alpine

# Install tools for health checks and monitoring
RUN apk add --no-cache openssl curl net-tools lsof procps bc

# Copy custom nginx configuration
COPY nginx/http2/nginx.conf /etc/nginx/nginx.conf

# Create directories for certificates and web content
RUN mkdir -p /etc/nginx/certs /usr/share/nginx/html

# Expose HTTPS port
EXPOSE 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -k -f https://localhost:443/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]