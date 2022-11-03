# wg-manager

WireGuard manager allow initialize WireGuard server and manage users.

```bash
Usage: ./wg-manager.sh [<options>] [command [arg]]
Options:
 -i : Init (Create server keys and configs)
 -c : Create new user
 -d : Delete user
 -p : Print user config
 -u <user> : User identifier (uniq field for vpn account)
 -s <server> : Server host for user connection
 -h : Usage
 ```

## Quick start

Run server (bare-metal or VPS) with Ubuntu 22.02

### Install WireGuard

```bash
apt install wireguard wireguard-tools -y
```

### Setup

 - Download this script (wg-manager.sh) from GitHub
 - Initialize WireGuard server: `./wg-manager.sh -i -s YOUR_SERVER_IP`
 - Add your user: `./wg-manager.sh -c -u my_user -p > wg-client.conf`
 - Install WireGuard on the client
 - Start client with config `wg-client.conf`
 
 
