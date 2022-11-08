#!/bin/bash

set -e

EVENT="{{ event_name }}"
WG_MANAGER="/etc/wireguard/wg-manager.sh"
SESSION_ID="{{ user.gen_session.id }}"

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
        if [ -z $SERVER_HOST ]; then
            echo "ERROR: set variable 'host_name' to server settings"
            exit 1
        fi

        apt update
        apt install -y \
            wireguard \
            wireguard-tools \
            qrencode \
            wget

        if [[ $CURL_REPO && ! -f $CURL ]]; then
            mkdir -p /opt/curl
            cd /opt/curl
            wget $CURL_REPO
            chmod 755 $CURL
        fi

        cd /etc/wireguard
        $CURL -s --fail-with-body https://danuk.github.io/wg-manager/wg-manager.sh > $WG_MANAGER
        chmod 700 $WG_MANAGER
        $WG_MANAGER -i -s $SERVER_HOST
        ;;
    CREATE)
        USER_CFG=$($WG_MANAGER -u "{{ us.id }}" -c -p)

        $CURL -s --fail-with-body -XPUT \
            -H "session-id: $SESSION_ID" \
            -H "Content-Type: text/plain" \
            {{ config.api.url }}/shm/v1/storage/manage/vpn \
            --data-binary "$USER_CFG"
        echo "done"
        ;;
    ACTIVATE)
        $WG_MANAGER -u "{{ us.id }}" -U
        echo "done"
        ;;
    BLOCK)
        $WG_MANAGER -u "{{ us.id }}" -L
        echo "done"
        ;;
    REMOVE)
        $WG_MANAGER -u "{{ us.id }}" -d
        $CURL -s --fail-with-body -XDELETE \
            -H "session-id: $SESSION_ID" \
            {{ config.api.url }}/shm/v1/storage/manage/vpn
        echo "done"
        ;;
    *)
        echo "Unknown event: $EVENT. Exit."
        exit 0
        ;;
esac


