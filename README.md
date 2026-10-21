# wg-manager

WireGuard manager allow initialize WireGuard server and manage users.

You can start the WireGuard server with one command, and then create (and delete) users.


```bash
Usage: ./wg-manager.sh [<options>] [command [arg]]
Options:
 -i : Init (Create server keys and configs)
 -c : Create new user
 -r : Restore user from existing private key (see -a, -k)
 -d : Delete user
 -L : Lock user
 -U : Unlock user
 -p : Print user config
 -q : Print user QR code
 -u <user> : User identifier (uniq field for vpn account)
 -s <server> : Server host for user connection
 -a <ip> : User IP address (for restore, default: next free)
 -k <key> : User private key (for restore)
 -I : Interface (default auto)
 -h : Usage
 ```

### Restore user

Re-create a user with a known private key and IP (aborts if the user already exists):

```bash
./wg-manager.sh -r -u my_user -a 10.10.10.5 -k KEY
```

## Quick start

Run server (bare-metal or VPS) with Ubuntu 22.02

### Install WireGuard

```bash
apt install wireguard wireguard-tools qrencode -y
```

### Setup

 - Download this script [wg-manager.sh](https://danuk.github.io/wg-manager/wg-manager.sh) from GitHub
 - Initialize WireGuard server: `./wg-manager.sh -i -s YOUR_SERVER_IP`
 - Add your user: `./wg-manager.sh -c -u my_user -p > wg-client.conf`
 - Install WireGuard on the client
 - Start client with config `wg-client.conf`


