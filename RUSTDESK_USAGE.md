# RustDesk Server Usage Guide

## What is RustDesk?
RustDesk is an open-source remote desktop software, similar to TeamViewer or AnyDesk. Your homelab is running a RustDesk **server** that acts as a relay/rendezvous point for RustDesk clients.

## Server Components Running
- **hbbs (21115-21116, 21118)**: RustDesk ID/Rendezvous Server - handles signaling
- **hbbr (21117, 21119)**: RustDesk Relay Server - relays traffic when direct connection fails

## How to Connect to Your RustDesk Server

### 1. Download RustDesk Client
Download the RustDesk client for your platform from: https://rustdesk.com/

### 2. Configure Client to Use Your Server
1. Open RustDesk client
2. Click on the menu (three dots) → Network
3. Set the following:
   - **ID Server**: `leopaska.xyz` or your server's IP address
   - **Relay Server**: Leave blank (it will auto-detect)
   - **API Server**: Leave blank
   - **Key**: Leave blank (unless you configured one)

### 3. Get Your Device ID
- Your device will get a unique 9-digit ID shown in the RustDesk client
- Share this ID with others to allow them to connect to your machine

### 4. Connect to Another Device
1. Enter the 9-digit ID of the remote device
2. Click Connect
3. The remote user must accept the connection
4. Enter the password when prompted

## Port Requirements
Make sure these ports are accessible:
- **TCP 21115-21116**: ID/Rendezvous server
- **UDP 21116**: ID/Rendezvous server
- **TCP 21117**: Relay server
- **TCP 21118**: Web client (if implemented)
- **TCP 21119**: Relay server

## Security Notes
1. **Always use strong passwords** on devices you're making accessible
2. Consider setting up a **key** on your RustDesk server for additional security
3. The server does NOT have a web interface - it only works with RustDesk clients
4. All traffic is encrypted end-to-end between clients

## Troubleshooting

### Can't connect to server
- Check firewall rules for ports 21115-21119
- Verify server is running: `docker ps | grep rustdesk`
- Check logs: `docker logs rustdesk-hbbs-leopaska`

### Connection is slow
- This usually means direct connection failed and traffic is being relayed
- Check if UDP 21116 is accessible from both clients
- Try to ensure both clients have good NAT traversal

### "Key Mismatch" error
- This means the server has a key configured
- Get the key from the server admin and enter it in Network settings

## Server Management Commands

```bash
# Check if RustDesk services are running
docker ps | grep rustdesk

# View logs
docker logs rustdesk-hbbs-leopaska  # Signal server logs
docker logs rustdesk-hbbr-leopaska  # Relay server logs

# Restart services
docker compose restart rustdesk-hbbs rustdesk-hbbr

# Get the server key (if configured)
docker exec rustdesk-hbbs-leopaska cat /root/id_ed25519.pub
```

## Why No Web Interface?
RustDesk server is purely a relay/signaling server. It doesn't provide remote access itself - it helps RustDesk clients find and connect to each other. The actual remote desktop happens peer-to-peer between clients when possible, or through the relay server when direct connection isn't possible.

To actually use remote desktop, you need:
1. RustDesk client installed on the machine you want to access
2. RustDesk client installed on the machine you're accessing from
3. Both configured to use your RustDesk server