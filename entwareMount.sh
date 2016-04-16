#!/ffp/bin/sh
ln -sf /ffp/opt /opt
[ -x /opt/sbin/kernel-2.6.24-support.sh ] && /opt/sbin/kernel-2.6.24-support.sh
/opt/etc/init.d/rc.unslung start
