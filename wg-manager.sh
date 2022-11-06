#!/bin/bash -e

APP=$(basename $0)
LOCKFILE="/tmp/$APP.lock"

trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT
if ! ln -s $APP $LOCKFILE 2>/dev/null; then
    echo "ERROR: script LOCKED"
    exit 15
fi

function usage {
  echo "Usage: $0 [<options>] [command [arg]]"
  echo "Options:"
  echo " -i : Init (Create server keys and configs)"
  echo " -c : Create new user"
  echo " -d : Delete user"
  echo " -p : Print user config"
  echo " -q : Print user QR code"
  echo " -u <user> : User identifier (uniq field for vpn account)"
  echo " -s <server> : Server host for user connection"
  echo " -h : Usage"
  exit 1
}

unset USER
umask 0077

while getopts ":icdpqhu:s:" opt; do
  case $opt in
     i) INIT=1 ;;
     c) CREATE=1 ;;
     d) DELETE=1 ;;
     p) PRINT_USER_CONFIG=1 ;;
     q) PRINT_QR_CODE=1 ;;
     u) USER="$OPTARG" ;;
     h) usage ;;
     s) SERVER_ENDPOINT="$OPTARG" ;;
    \?) echo "Invalid option: -$OPTARG" ; exit 1 ;;
     :) echo "Option -$OPTARG requires an argument" ; exit 1 ;;
  esac
done

[ $# -lt 1 ] && usage

HOME_DIR="/etc/wireguard"
SERVER_NAME="wg-server"
SERVER_IP_PREFIX="10.10.10"
SERVER_PORT=39547
SERVER_INTERFACE="eth0" # ens4

function reload_server {
    wg syncconf ${SERVER_NAME} <(wg-quick strip ${SERVER_NAME})
}

function init {
    if [ -z "$SERVER_ENDPOINT" ]; then
        echo "ERROR: Server required"
        exit 1
    fi

    mkdir -p "$HOME_DIR/keys/${SERVER_NAME}"
    echo -n "$SERVER_ENDPOINT" > "keys/.server"

    if [ -f "keys/${SERVER_NAME}/private.key" ]; then
        echo "ERROR: Server has already been initialized"
        exit 0
    fi

    echo -n "1" > "keys/.last_ip"

    wg genkey | tee "keys/${SERVER_NAME}/private.key" | wg pubkey > "keys/${SERVER_NAME}/public.key"

    SERVER_PVT_KEY=$(cat "keys/$SERVER_NAME/private.key")

cat <<EOF > "${HOME_DIR}/$SERVER_NAME.conf"
[Interface]
Address = ${SERVER_IP_PREFIX}.1/32
ListenPort = ${SERVER_PORT}
PrivateKey = ${SERVER_PVT_KEY}
PostUp = iptables -t nat -A POSTROUTING -o ${SERVER_INTERFACE} -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o ${SERVER_INTERFACE} -j MASQUERADE

EOF

    echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
    sysctl -p

    systemctl enable wg-quick@${SERVER_NAME}
    wg-quick up ${SERVER_NAME}

    echo "Server initialized successfully"
    exit 0
}

function create {
    if [ -f "${HOME_DIR}/keys/${USER}/${USER}.conf" ]; then
        echo "ERROR: user already exists"
        exit 1
    fi

    SERVER_ENDPOINT=$(cat "keys/.server")

    LAST_IP=$[$(cat "keys/.last_ip") + 1]
    if [ $LAST_IP -gt 255 ]; then
        echo "ERROR: can't determine new address"
        exit 3
    fi

    echo -n "${LAST_IP}" > "keys/.last_ip"
    USER_IP="${SERVER_IP_PREFIX}.${LAST_IP}/32"

    mkdir "keys/${USER}"
    wg genkey | tee "keys/${USER}/private.key" | wg pubkey > "keys/${USER}/public.key"

    USER_PVT_KEY=$(cat "keys/${USER}/private.key")
    USER_PUB_KEY=$(cat "keys/${USER}/public.key")
    SERVER_PUB_KEY=$(cat "keys/$SERVER_NAME/public.key")

cat <<EOF >> "$HOME_DIR/$SERVER_NAME.conf"
# BEGIN ${USER}
[Peer]
PublicKey = ${USER_PUB_KEY}
AllowedIPs = ${USER_IP}
# END ${USER}

EOF

cat <<EOF > "${HOME_DIR}/keys/${USER}/${USER}.conf"
[Interface]
Address = ${USER_IP}
PrivateKey = ${USER_PVT_KEY}
DNS = 8.8.8.8

[Peer]
PublicKey = ${SERVER_PUB_KEY}
Endpoint = ${SERVER_ENDPOINT}:${SERVER_PORT}
PersistentKeepalive = 20
AllowedIPs = 0.0.0.0/0
EOF

    reload_server
}

cd $HOME_DIR

if [ $INIT ]; then
    init
    exit 0;
fi

if [ ! -f "keys/$SERVER_NAME/public.key" ]; then
    echo "ERROR: Run init script before"
    exit 2
fi

if [ -z "${USER}" ]; then
    echo "ERROR: User required"
    exit 1
fi

if [ $CREATE ]; then
    create
fi

if [ $DELETE ]; then
    sed -i "/# BEGIN ${USER}/,/# END ${USER}/d" "${HOME_DIR}/$SERVER_NAME.conf"
    rm -rf "${HOME_DIR}/keys/${USER}"
    reload_server
    exit 0
fi

if [ $PRINT_USER_CONFIG ]; then
    cat "${HOME_DIR}/keys/${USER}/${USER}.conf"
elif [ $PRINT_QR_CODE ]; then
    qrencode -t ansiutf8 < "${HOME_DIR}/keys/${USER}/${USER}.conf"
fi

exit 0

