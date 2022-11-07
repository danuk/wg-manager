#!/bin/bash -e

EVENT="{{ event_name }}"
WG_MANAGER="/etc/wireguard/wg-manager.sh"

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
            curl
        cd /etc/wireguard
        curl -s https://danuk.github.io/wg-manager/wg-manager.sh > $WG_MANAGER
        chmod 700 $WG_MANAGER
        $WG_MANAGER -i -s $SERVER_HOST
        ;;
    CREATE)
        SESSION_ID="{{ user.gen_session.id }}"
        USER_CFG=$($WG_MANAGER -c "{{ us.id }}" -p)

        if [ $? -ne 0]; then
            echo "ERROR: can't create user"
            exit 2
        fi

        curl -s -XPUT \
            -H "session-id: $SESSION_ID" \
            -H "Content-Type: text/plain" \
            {{ config.api.url }}/shm/v1/storage/manage/vpn \
            --data-binary $USER_CFG
        echo "done"
        ;;
    REMOVE)
        $WG_MANAGER -c "{{ us.id }}" -d
        echo "done"
        ;;
    *)
        echo "Unknown event: $EVENT. Exit."
        exit 0
        ;;
esac


