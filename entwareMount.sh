#!/ffp/bin/sh
# Author: Anirudh Acharya

entware_start()
{
    echo "Starting Entware-ng..."
    ln -sf /ffp/opt /opt
    [ -x /opt/sbin/kernel-2.6.24-support.sh ] && /opt/sbin/kernel-2.6.24-support.sh
    /opt/etc/init.d/rc.unslung start
}

entware_stop()
{
    echo -n "Stopping Entware-ng..."
    /opt/etc/init.d/rc.unslung stop
    echo .
}

entware_status()
{
    /opt/etc/init.d/rc.unslung check
}

case $1 in
    start)
            entware_start
            ;;
    stop)
            entware_stop
            ;;
    status)
            entware_status
            ;;
    *)
            echo "Usage $0 [ start | stop | status ]"
            ;;
esac
