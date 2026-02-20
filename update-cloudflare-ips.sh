#!/bin/bash
# =============================================================================
# CLOUDFLARE IP UPDATER
# =============================================================================
# Updates nginx/snippets/cloudflare.conf with latest Cloudflare IP ranges
# Run periodically via cron: 0 0 * * 0 /path/to/update-cloudflare-ips.sh
# =============================================================================

set -euo pipefail

CLOUDFLARE_CONF="/etc/nginx/snippets/cloudflare.conf"
TEMP_FILE=$(mktemp)

cat > "$TEMP_FILE" << 'HEADER'
# =============================================================================
# CLOUDFLARE CONFIGURATION - AUTO-GENERATED
# =============================================================================
# Last updated: $(date '+%Y-%m-%d %H:%M:%S')
# Source: https://www.cloudflare.com/ips/
# =============================================================================

# -----------------------------------------------------------------------------
# CLOUDFLARE IPv4 RANGES
# -----------------------------------------------------------------------------

HEADER

# Fetch IPv4 ranges
echo "# Fetching Cloudflare IPv4 ranges..."
curl -s https://www.cloudflare.com/ips-v4 | while read -r ip; do
    echo "set_real_ip_from $ip;" >> "$TEMP_FILE"
done

cat >> "$TEMP_FILE" << 'MIDDLE'

# -----------------------------------------------------------------------------
# CLOUDFLARE IPv6 RANGES
# -----------------------------------------------------------------------------

MIDDLE

# Fetch IPv6 ranges
echo "# Fetching Cloudflare IPv6 ranges..."
curl -s https://www.cloudflare.com/ips-v6 | while read -r ip; do
    echo "set_real_ip_from $ip;" >> "$TEMP_FILE"
done

cat >> "$TEMP_FILE" << 'FOOTER'

# -----------------------------------------------------------------------------
# REAL IP HEADER
# -----------------------------------------------------------------------------

real_ip_header CF-Connecting-IP;
real_ip_recursive on;
FOOTER

# Validate and replace
if nginx -t 2>/dev/null; then
    cp "$TEMP_FILE" "$CLOUDFLARE_CONF"
    echo "Cloudflare IPs updated successfully"
    nginx -s reload
else
    echo "Nginx config test failed, keeping old configuration"
    rm "$TEMP_FILE"
    exit 1
fi

rm -f "$TEMP_FILE"
