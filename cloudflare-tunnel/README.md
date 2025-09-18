# Cloudflare Tunnels + Route53 Setup

This setup provides the **most secure and cost-effective** solution for your homelab:

## 🎯 **What You Get**

- ✅ **Route53** - Full domain management control
- ✅ **Cloudflare Tunnels** - Secure, encrypted connection (no public IP exposure)
- ✅ **Cloudflare Security** - DDoS protection, WAF, bot protection
- ✅ **Cloudflare Performance** - Global CDN, caching
- ✅ **Zero Public IP Exposure** - Your homelab is completely hidden
- ✅ **Multi-Domain Support** - Easy to add new domains
- ✅ **Multi-AWS-Account** - Works across all your AWS accounts

## 💰 **Cost**

- **Route53**: ~$0.50/month (DNS queries only)
- **Cloudflare Tunnels**: **FREE** (unlimited tunnels)
- **Cloudflare Security**: **FREE** (basic tier)
- **Total**: ~$0.50/month

## 🔒 **Security Level**

- **Maximum** - Your homelab is completely hidden
- **No public IP exposure**
- **Encrypted tunnels**
- **DDoS protection**
- **WAF protection**

## 🚀 **Quick Start**

1. **Get Cloudflare API Token:**
   - Go to https://dash.cloudflare.com/profile/api-tokens
   - Create a token with Zone:Edit permissions
   - Update the `CLOUDFLARE_API_TOKEN` variable in `setup.sh`

2. **Update your domain:**
   - Change `yourdomain.com` to your actual domain
   - Update the `HOSTED_ZONE_ID` in the Route53 script

3. **Run the setup:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

4. **Start the tunnel:**
   ```bash
   sudo systemctl enable cloudflare-tunnel.service
   sudo systemctl start cloudflare-tunnel.service
   ```

5. **Update Route53 records:**
   ```bash
   ./update-route53.sh
   ```

6. **Configure Cloudflare security settings:**
   - Go to your domain in Cloudflare dashboard
   - Enable security features (WAF, Bot Fight Mode, etc.)
   - Configure SSL/TLS settings

## 📁 **File Structure**

```
cloudflare-tunnel/
├── setup.sh              # Main setup script
├── update-route53.sh      # Route53 update script
├── config.yml            # Tunnel configuration (generated)
├── credentials.json      # Tunnel credentials (generated)
└── tunnel-id.txt         # Tunnel ID (generated)
```

## 🔧 **Configuration**

### **Tunnel Configuration (`config.yml`)**
The tunnel configuration defines which services are exposed and how they're routed.

### **Route53 Update Script (`update-route53.sh`)**
This script updates your Route53 records to point to Cloudflare's IPs.

### **Systemd Service (`cloudflare-tunnel.service`)**
This service runs the tunnel automatically on boot and restarts it if it fails.

## 🌐 **Adding New Domains**

1. **Add the domain to Route53:**
   - Create A records pointing to Cloudflare IPs
   - Use the `update-route53.sh` script

2. **Add the domain to tunnel config:**
   - Edit `config.yml`
   - Add new ingress rules
   - Restart the tunnel service

3. **Configure in Cloudflare:**
   - Add the domain to your Cloudflare account
   - Configure security settings

## 🔍 **Monitoring**

- **Tunnel Status:** `sudo systemctl status cloudflare-tunnel.service`
- **Tunnel Logs:** `journalctl -u cloudflare-tunnel.service -f`
- **Route53 Status:** Check your Route53 console

## 🛠️ **Troubleshooting**

### **Tunnel Not Starting**
- Check if cloudflared is installed: `which cloudflared`
- Check tunnel credentials: `cat credentials.json`
- Check tunnel configuration: `cloudflared tunnel validate config.yml`

### **DNS Not Resolving**
- Check Route53 records: `dig yourdomain.com`
- Check Cloudflare DNS: `dig yourdomain.com @1.1.1.1`
- Verify tunnel is running: `sudo systemctl status cloudflare-tunnel.service`

### **Services Not Accessible**
- Check Traefik configuration
- Check tunnel ingress rules
- Check Cloudflare security settings

## 🔐 **Security Best Practices**

1. **Enable Cloudflare Security:**
   - WAF (Web Application Firewall)
   - Bot Fight Mode
   - DDoS Protection
   - Rate Limiting

2. **Configure SSL/TLS:**
   - Set SSL/TLS mode to "Full (strict)"
   - Enable HSTS
   - Enable Always Use HTTPS

3. **Monitor Access:**
   - Enable Cloudflare Analytics
   - Set up alerts for suspicious activity
   - Regularly review access logs

## 📊 **Performance Optimization**

1. **Enable Caching:**
   - Configure page rules for static content
   - Set appropriate cache TTLs

2. **Optimize Images:**
   - Enable Cloudflare Image Resizing
   - Use WebP format

3. **Enable Compression:**
   - Brotli compression
   - Gzip compression

## 🚀 **Scaling**

This setup scales easily:
- **Add more domains:** Just add them to Route53 and tunnel config
- **Add more services:** Add ingress rules to tunnel config
- **Add more AWS accounts:** Use different Route53 hosted zones
- **Add more tunnels:** Create additional tunnel configurations

## 📞 **Support**

If you need help:
1. Check the troubleshooting section above
2. Review Cloudflare documentation
3. Check the tunnel logs
4. Verify your configuration

