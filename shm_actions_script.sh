#!/bin/bash

set -e

EVENT="{{ event_name }}"
WG_MANAGER="/etc/wireguard/wg-manager.sh"
SESSION_ID="{{ user.gen_session.id }}"
API_URL="{{ config.api.url }}"

# We need the --fail-with-body option for curl.
# It has been added since curl 7.76.0, but almost all Linux distributions do not support it yet.
# If your distribution has an older version of curl, you can use it (just comment CURL_REPO)
CURL_REPO="https://github.com/moparisthebest/static-curl/releases/download/v7.86.0/curl-amd64"
CURL="/opt/curl/curl-amd64"
#CURL="curl"

echo "EVENT=$EVENT"

case $EVENT in
    INIT)
        SERVER_HOST="{{ server.settings.host_name }}"
        SERVER_INTERFACE="{{ server.settings.host_interface }}"
        if [ -z $SERVER_HOST ]; then
            echo "ERROR: set variable 'host_name' to server settings"
            exit 1
        fi
        
        echo "Install required packages"
        apt update
        apt install -y \
            iproute2 \
            iptables \
            wireguard \
            wireguard-tools \
            qrencode \
            curl \
            wget
            
        echo "Check domain: $API_URL"
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $API_URL/shm/v1/test)
        if [ $HTTP_CODE -ne '200' ]; then
            echo "ERROR: incorrect API URL: $API_URL"
            echo "Got status: $HTTP_CODE"
            exit 1
        fi

        if [[ $CURL_REPO && ! -f $CURL ]]; then
            echo "Install modern curl"
            mkdir -p /opt/curl
            cd /opt/curl
            wget $CURL_REPO
            chmod 755 $CURL
        fi

        echo "Download wg-manager.sh"
        cd /etc/wireguard
        $CURL -s --fail-with-body https://danuk.github.io/wg-manager/wg-manager.sh > $WG_MANAGER

        echo "Init server"
        chmod 700 $WG_MANAGER
        if [ $SERVER_INTERFACE ]; then
            $WG_MANAGER -i -s $SERVER_HOST -I $SERVER_INTERFACE
        else
            $WG_MANAGER -i -s $SERVER_HOST
        fi
        ;;
    CREATE)
        echo "Create new user"
        USER_CFG=$($WG_MANAGER -u "{{ us.id }}" -c -p)

        echo "Upload user key to SHM"
        $CURL -s --fail-with-body -XPUT \
            -H "session-id: $SESSION_ID" \
            -H "Content-Type: text/plain" \
            $API_URL/shm/v1/storage/manage/vpn{{ us.id }} \
            --data-binary "$USER_CFG"
        echo "done"
        ;;
    ACTIVATE)
        echo "Activate user"
        $WG_MANAGER -u "{{ us.id }}" -U
        echo "done"
        ;;
    BLOCK)
        echo "Block user"
        $WG_MANAGER -u "{{ us.id }}" -L
        echo "done"
        ;;
    REMOVE)
        echo "Remove user"
        $WG_MANAGER -u "{{ us.id }}" -d

        echo "Remove user key from SHM"
        $CURL -s --fail-with-body -XDELETE \
            -H "session-id: $SESSION_ID" \
            $API_URL/shm/v1/storage/manage/vpn{{ us.id }}
        echo "done"
        ;;
    *)
        echo "Unknown event: $EVENT. Exit."
        exit 0
        ;;
esac


