# Cloudflare Configuration for WordPress

## Overview

This guide covers optimal Cloudflare settings for WordPress sites using Nginx.

## Files Created

| File | Purpose |
|------|---------|
| `nginx/snippets/cloudflare.conf` | Restore real visitor IPs |
| `nginx/snippets/cloudflare-cache.conf` | Cache header reference |
| `update-cloudflare-ips.sh` | Auto-update CF IP ranges |

## Nginx Configuration

### 1. Enable Real IP Restoration

Edit `/etc/nginx/nginx.conf` and uncomment:

```nginx
include snippets/cloudflare.conf;
```

This ensures logs and rate limiting use the real visitor IP, not Cloudflare's.

### 2. Test and Reload

```bash
sudo nginx -t && sudo nginx -s reload
```

### 3. Schedule IP Updates (Optional)

```bash
sudo chmod +x /path/to/update-cloudflare-ips.sh
echo "0 0 * * 0 root /path/to/update-cloudflare-ips.sh" | sudo tee /etc/cron.d/cloudflare-ips
```

---

## Cloudflare Dashboard Settings

### SSL/TLS Tab

| Setting | Recommended | Why |
|---------|-------------|-----|
| **SSL/TLS Mode** | **Full (Strict)** | Your server has valid SSL cert |
| **Edge Certificates > Always Use HTTPS** | ON | Force HTTPS |
| **Edge Certificates > Minimum TLS Version** | TLS 1.2 | Security best practice |
| **Edge Certificates > TLS 1.3** | ON | Better performance + security |
| **Edge Certificates > Automatic HTTPS Rewrites** | ON | Fix mixed content |
| **Edge Certificates > HTTP Strict Transport Security (HSTS)** | Enable | Already in nginx, but belt + suspenders |

**HSTS Settings:**
- Max-Age: 12 months (31536000)
- Include subdomains: Yes
- Preload: Yes (after testing)
- No-Sniff Header: Yes

### Speed Tab

| Setting | Recommended | Why |
|---------|-------------|-----|
| **Optimization > Early Hints** | ON | 103 Early Hints for faster LCP |
| **Optimization > Rocket Loader** | OFF | Conflicts with many WP plugins |
| **Optimization > Auto Minify** | OFF | Better handled by WP caching plugins |
| **Optimization > Brotli** | ON | Smaller files than gzip |
| **Optimization > HTTP/2** | ON | Multiplexing |
| **Optimization > HTTP/3 (QUIC)** | ON | Better mobile/lossy networks |

### Caching Tab

| Setting | Recommended | Why |
|---------|-------------|-----|
| **Caching Level** | Standard | Default is fine |
| **Browser Cache TTL** | Respect Existing Headers | Let nginx control |
| **Always Online** | ON | Serve cached pages if origin down |
| **Development Mode** | OFF | Only for debugging |
| **Edge Cache TTL** | 1 month (default) | For static assets |

### Page Rules (Legacy) or Cache Rules (New)

Create rules to bypass cache for dynamic WordPress pages:

**Rule 1: Bypass Cache for Admin**
```
URL: *example.com/wp-admin/*
Settings:
  - Cache Level: Bypass
  - Security Level: High
```

**Rule 2: Bypass Cache for Login**
```
URL: *example.com/wp-login.php*
Settings:
  - Cache Level: Bypass
  - Security Level: High
```

**Rule 3: Bypass Cache for AJAX**
```
URL: *example.com/wp-admin/admin-ajax.php*
Settings:
  - Cache Level: Bypass
```

**Rule 4: Bypass Cache for WooCommerce**
```
URLs:
  - *example.com/cart/*
  - *example.com/checkout/*
  - *example.com/my-account/*
Settings:
  - Cache Level: Bypass
```

**Rule 5: Cache Static Assets Aggressively**
```
URL: *example.com/wp-content/*
Settings:
  - Cache Level: Cache Everything
  - Edge Cache TTL: 1 month
  - Browser Cache TTL: 1 year
```

### Security Tab

| Setting | Recommended | Why |
|---------|-------------|-----|
| **Security Level** | Medium | Balance protection/accessibility |
| **Bot Fight Mode** | ON | Block bad bots |
| **Challenge Passage** | 30 minutes | Reduces repeat challenges |
| **Browser Integrity Check** | ON | Block headless browsers |
| **Under Attack Mode** | OFF | Only during DDoS |

### WAF (Web Application Firewall)

| Setting | Recommended |
|---------|-------------|
| **Managed Rulesets > Cloudflare Managed Ruleset** | ON |
| **Managed Rulesets > Cloudflare OWASP Core Ruleset** | ON (Medium sensitivity) |
| **Managed Rulesets > Cloudflare Leaked Credentials Check** | ON |

**Custom WAF Rules for WordPress:**

```
# Block xmlrpc.php (except Jetpack IPs)
Rule: http.request.uri.path eq "/xmlrpc.php" and not ip.src in {122.248.245.244 54.217.201.243 54.232.116.4 192.0.80.0/20 192.0.96.0/20 192.0.112.0/20 195.234.108.0/22}
Action: Block

# Block wp-config access attempts
Rule: http.request.uri.path contains "wp-config"
Action: Block

# Rate limit login attempts
Rule: http.request.uri.path eq "/wp-login.php" and http.request.method eq "POST"
Action: Rate Limit (5 requests/10 seconds)
```

### Network Tab

| Setting | Recommended | Why |
|---------|-------------|-----|
| **HTTP/2** | ON | Already enabled |
| **HTTP/3 (QUIC)** | ON | Better for mobile |
| **IPv6 Compatibility** | ON | Future-proof |
| **WebSockets** | ON if needed | For real-time features |
| **Onion Routing** | OFF | Unless Tor users needed |
| **IP Geolocation** | ON | Useful for analytics/blocking |

### Scrape Shield Tab

| Setting | Recommended | Why |
|---------|-------------|-----|
| **Email Address Obfuscation** | ON | Hide emails from scrapers |
| **Server-side Excludes** | ON | Hide content from bad bots |
| **Hotlink Protection** | Optional | Prevents image theft |

---

## WordPress Plugin Configuration

### If Using WP Rocket / LiteSpeed Cache / W3 Total Cache:

1. **Disable CDN features** - Cloudflare handles this
2. **Disable minification** - Or use only one (plugin OR Cloudflare)
3. **Enable page caching** - Works alongside Cloudflare
4. **Configure cache purge API** - Auto-purge on publish

### Cloudflare Plugin for WordPress

Install and configure:
```
Plugins > Add New > Search "Cloudflare"
```

Settings:
- **Automatic Platform Optimization (APO)** - $5/mo, excellent for WordPress
- **Cache Purge** - Auto-purge on post update
- **Development Mode Toggle** - From WP admin

---

## Performance Testing Checklist

After configuration, verify:

- [ ] SSL/TLS shows Full (Strict) with no warnings
- [ ] `curl -I https://example.com` shows `cf-cache-status` header
- [ ] Static assets return `cf-cache-status: HIT`
- [ ] wp-admin pages return `cf-cache-status: DYNAMIC` or `BYPASS`
- [ ] Real visitor IPs appear in Nginx logs (not 162.158.x.x)
- [ ] Rate limiting works with real IPs
- [ ] PageSpeed scores improved

## Cache Purge

From terminal (with API token):
```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/ZONE_ID/purge_cache" \
  -H "Authorization: Bearer API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}'
```

Or specific URLs:
```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/ZONE_ID/purge_cache" \
  -H "Authorization: Bearer API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"files":["https://example.com/page-to-purge/"]}'
```

---

## Troubleshooting

### Cache Not Working
1. Check `cf-cache-status` header
2. Verify no `Set-Cookie` on cacheable pages
3. Check Page Rules order (first match wins)

### Real IP Not Showing
1. Verify `include snippets/cloudflare.conf;` is enabled
2. Run `nginx -t` to check syntax
3. Check Cloudflare IP ranges are current

### SSL Errors
1. Ensure origin SSL cert is valid
2. Check SSL mode is Full (Strict)
3. Verify cert covers domain + www

### 522/524 Errors (Timeouts)
1. Check origin server is up
2. Increase PHP timeouts
3. Check firewall allows Cloudflare IPs
