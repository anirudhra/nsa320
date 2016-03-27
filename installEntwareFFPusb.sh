#!/ffp/bin/sh
# ============================================================================
#
# This file is part of the 
# 'Entware-ng-stick 20160216 for ZyXEL NSA and NAS series'
# package
#
# http://zyxel.nas-central.org/wiki/Entware-ng
#
# This program is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# Original Author: Mijzelf <Mijzelf@live.com>
# Original source: http://zyxel.nas-central.org/wiki/Entware-ng#Entware-ng_Stick
# Modified by: infrareddude
# Purpose: One time installation of entrware-ng on /opt on FFP USB
# All credits go to Mijzelf for the original work
#
# ============================================================================

#
# This package modifies the original script for one time installation of entware-ng
# in /opt and skips all boot stages
#

MOUNT_TIMEOUT=300 # If this value <> 0, the script will wait for the harddisk(s) to be mounted
# before Entware is started. When 0, or when not set, the scripts are called from usb_key_func.sh


PKG_VERSION=20160216
PKG_NAME="Entware-ng"
PKG_STICK=1


# ========================================
# function RotateLogfile
# Arguments: directory logfile
# Rotates logfile, compresses old versions
# ========================================
RotateLogfile()
{
    logpath=$1

    oldlog=${logpath}.9.gz
    if [ -r ${oldlog} ] ; then
        echo rm ${oldlog}
        rm ${oldlog}
    fi

    for nr in 8 7 6 5 4 3 2 1
    do
        oldlog=${logpath}.${nr}.gz
        if [ -r ${oldlog} ] ; then
	    newnr=`expr $nr + 1`
	    newlog=${logpath}.${newnr}.gz
	    echo mv ${oldlog} ${newlog}
	    mv ${oldlog} ${newlog}
	fi
    done
    
    if [ -r ${logpath} ] ; then
	cat ${logpath} | gzip -c >${oldlog}
	rm ${logpath}
    fi
}

# =========================================
# function FilterLogfile
# 
# Is placed in stdout to create a pretty logfile
# with timestamps and indents
#=========================================
FilterLogfile()
{
        local logfile=$1
	local pipe=$2
	local tempfile=$3

	if [ -f $logfile ] ; then
	    exec >>$logfile
	    echo "Reopened logfile at $( date )"
	else
	    exec >$logfile
	    echo "Opened logfile at $( date )"
	fi
    
	if [ "$tempfile" != "" ] ; then
	    echo "Flushing memory buffer"
	    while read line 
	    do
		echo "    ${line}"
	    done <$tempfile
	    rm $tempfile
	    echo "Flushing done"
	fi
    
	local indent=""
    
	while read line 
	do
		if [ "${line:0:3}" = "+++" ] ; then
			case "${line:3}" in
				Indent*)
					if [ "${line:9:1}" = "+" ] ; then
						indent="    $indent"
					else
						indent="${indent:4}"
					fi
					;;
				Move*)
					local moveto=${line:8}
					echo "[$( date +"%T" )] Move logfile from ${logfile} to ${moveto}"
					mkdir -p $( dirname ${moveto} )
					[ -f ${moveto} ] && RotateLogfile ${moveto} 
					exec 1>&-
					mv ${logfile} ${moveto}
					[ $? -eq 0 ] && logfile=${moveto} || echo Move failed. >>${logfile} 
					exec 1>>${logfile}
					;;
				Append*)
					local appendto=${line:10}
					echo "[$( date +"%T" )] Append logfile ${logfile} to ${appendto}"
					mkdir -p $( dirname ${appendto} )
					exec 1>&-
					cat ${logfile} >>${appendto}
					if [ $? -eq 0 ] ; then
					    rm ${logfile}
					    logfile=${appendto}
					else
					    echo Append failed. >>${logfile} 
					fi
					exec 1>>${logfile}
					
			esac
			
			continue
		fi
	
		echo "[$( date +"%T" )] ${indent}${line}"
		
	done <$pipe

	echo Closed logfile at $( date )
	rm $pipe
	exit 0
}

#===============================================
# function OpenLogfile
#
# Open or close a logfile. An open logfile is routed
# through FilterLogfile
#===============================================
OpenLogfile()
{
	[ "$1" = "" ] && return

	if [ "$1" = "-" ] ; then
		exec 1>&3
		exec 3>&-
		exec 2>&4
		exec 4>&-
		rm /tmp/Entware-ng*.pipe
		return
	fi

	mkdir -p $( dirname ${1} )

	exec 3>&1
	exec 4>&2

	if [ "$2" != "" ] ; then
		# First opening
		exec 2>&1 1>>$2
		RotateLogfile $1
	fi

	local pipe=/tmp/Entware-ng.$$.pipe
	mknod ${pipe} p

	filter=FilterLogfile
	[ "${3}" != "" ] && filter="${3} filter"
	
	${filter} ${1} $pipe ${2} 3>&- 4>&- &
	
	exec 1>${pipe} 2>&1
}

PKG_OLDKERNEL=0

Install()
{
	for folder in usr bin etc/init.d lib/opkg sbin share tmp var/lock var/run
	do
		if [ -d "/opt/$folder" ]
		then
			echo "Warning: Folder /opt/$folder exists!"
			echo "Warning: If something goes wrong please clean /opt folder and try again."
		else
			mkdir -p /opt/$folder
		fi
	done

	echo "Info: Opkg package manager deployment..."
	local CURARCH="armv5"
	
	if [ ${PKG_OLDKERNEL} -eq 0 ] ; then
		# ArmV7 on oldkernel should use Armv5 old kernel libs
		# Didn't compile the Armv7 variants
	
		if uname -a | grep armv7 >/dev/null
		then
			CURARCH="armv7"
		fi
	fi
	
	local DLOADER="ld-linux.so.3"
	local URL=http://pkg.entware.net/binaries/$CURARCH/installer
	local MIJZELF_URL=http://downloads.zyxel.nas-central.org/Users/Mijzelf/Entware-ng/binaries/${CURARCH}
	
	wget $URL/opkg -O /opt/bin/opkg
	chmod +x /opt/bin/opkg
	wget $URL/opkg.conf -O /opt/etc/opkg.conf
	wget $URL/libgcc_s.so.1 -O /opt/lib/libgcc_s.so.1

	local OKV=""
	if [ $PKG_OLDKERNEL -eq 1 ] ; then
		URL=${MIJZELF_URL}/installer
		OKV="-2.6.24"
	fi
	
	wget $URL/ld-2.22.so${OKV} -O /opt/lib/ld-2.22.so
	wget $URL/libc-2.22.so${OKV} -O /opt/lib/libc-2.22.so
		
	cd /opt/lib
	chmod +x ld-2.22.so
	ln -s ld-2.22.so $DLOADER
	ln -s libc-2.22.so libc.so.6
	
	echo "Info: Basic packages installation..."
	sed -i "2isrc/gz Mijzelf ${MIJZELF_URL}" /opt/etc/opkg.conf
	/opt/bin/opkg update
	
	[ $PKG_OLDKERNEL -eq 1 ] && /opt/bin/opkg install kernel-2.6.24-support
	/opt/bin/opkg install libc
	[ -x /opt/sbin/kernel-2.6.24-support.sh ] && /opt/sbin/kernel-2.6.24-support.sh
	/opt/bin/opkg install libpthread
	[ -x /opt/sbin/kernel-2.6.24-support.sh ] && /opt/sbin/kernel-2.6.24-support.sh
	/opt/bin/opkg install entware-opt

	# entware-opt overwrites our 2.6.24 support, so restore it
	[ -x /opt/sbin/kernel-2.6.24-support.sh ] && /opt/sbin/kernel-2.6.24-support.sh

	/opt/bin/opkg install profile-hook
	
	if [ ! -f /opt/usr/lib/locale/locale-archive ]
	then
    		wget http://pkg.entware.net/binaries/other/locale-archive -O /opt/usr/lib/locale/locale-archive
	fi

	echo "Info: Congratulations!"
	echo "Info: If there are no errors above then Entware-ng was successfully initialized."
	echo "Info: Found a Bug? Please report at https://github.com/Entware-ng/Entware-ng/issues"
}

Startup()
{
	local optdir=${PKG_ROOT}/opt
	local tmplog=/tmp/${PKG_NAME}.$$.log
	echo "Starting up" >$tmplog

	if [ -x ${optdir}/redirect.sh ] ; then
		local alternate=$( ${optdir}/redirect.sh )
		if [ -d ${alternate} ] ; then
			optdir=${alternate}
			echo "/opt redirected to ${optdir}" >>$tmplog
		fi
	fi

	mkdir -p ${optdir}/var/log
	OpenLogfile ${optdir}/var/log/Entware-ng.log $tmplog

	[ -h /opt ] && rm /opt
	[ -d /opt ] && echo "FATAL: /opt is a directory" && OpenLogfile "-" && exit 0
	[ -f /opt ] && mv /opt "/opt.$( date )"
	
	echo "Create symlink /opt -> ${optdir}"
	ln -s ${optdir} /opt

	local starter=/opt/etc/init.d/rc.unslung

	if [ ! -f ${starter} ] ; then
		echo "${starter} is not available, start installer"
		echo "+++Indent+"
		mkdir -p ${optdir}
		chmod 755 ${optdir}
		Install
		if [ $? -ne 0 ] ; then
		    	OpenLogfile -
			return
		fi
		echo "+++Indent-"
	fi
			
	[ -x /opt/sbin/kernel-2.6.24-support.sh ] && /opt/sbin/kernel-2.6.24-support.sh

	echo "Execute ${starter} start"
	echo "+++Indent+"
	${starter} start	
	echo "+++Indent-"
	echo "Done ${starter} start"
    	OpenLogfile -
}

Shutdown()
{
	OpenLogfile /opt/var/log/Entware-ng.log
	
	local starter=/opt/etc/init.d/rc.unslung
	echo "Execute ${starter} stop"
	echo "+++Indent+"
	${starter} stop
	echo "+++Indent-"
	echo "Done ${starter} stop"

	OpenLogfile -
}



SayHello()
{
infodir=/zyxel/mnt/info
[ -d /firmware/mnt/info ] && infodir=/firmware/mnt/info
model=unknown
[ -f /etc/modelname ] && model=` head -n 1 /etc/modelname `
modelid=` cat ${infodir}/modelid `
fwversion=` cat ${infodir}/fwversion `

stick=""
[ "${PKG_STICK}" = "1" ] && stick="-stick-$PKG_VERSION"

[ "${PKG_UPGRADING}" != "" -a ${PKG_UPGRADING} -gt 0 ] && upgrading="-upgrading"


# Say hello to the author of this package. The requested file doesn't exist, 
# so wget will get a 404, but it will give a logline in my webserver logs.
wget -q -t 2 -T 2 "http://mijzelf.duckdns.org/hello_author.php?${PKG_NAME}${upgrading}-${model}-${modelid}-${fwversion}${stick}" -O - 2>/dev/null

# get return value on zero again:
cat /proc/self/cmdline >/dev/null

}


IsOldKernel()
{
	# Find current kernel version
	local kernelversion=$( uname -r )
	local kv1=$( echo $kernelversion | cut -d '.' -f 1 )
	local kv2=$( echo $kernelversion | cut -d '.' -f 2 )
	local kv3=$( echo $kernelversion | cut -d '.' -f 3 )

	let kv1=kv1*10000
	let kv2=kv2*100
	let kv3=kv3+kv2+kv1

	# if < 2.6.32 (default target of Entware), enable 'old kernel' functionality
	[ $kv3 -lt 20632 ] && return 0
	
	return 1
}

[ "${PKG_STICK}" != "1" ] && IsOldKernel && sed -i "s|^PKG_OLDKERNEL=0|PKG_OLDKERNEL=1|" ${PKG_ROOT}/etc/init.d/${PKG_NAME}



#########################################################
## Stage1 is called from usb_key_func.sh
## (see http://zyxel.nas-central.org/wiki/Usb_key_func.sh)
## 

Stage1()
{
    # The script can be executed several times
    [ -x /tmp/${PKG_NAME}.sh -o -d /opt ] && exit 1


    local logfile=/tmp/${PKG_NAME}.log.tmp
    echo "Starting ${PKG_NAME} stick ${PKG_VERSION}" >${logfile}
    echo "Running ${0} stage1 \"$@\"" >>${logfile}
    
    # copy myself to /tmp:
    echo "Copy myself to /tmp" >>${logfile}
    
    cp $0 /tmp/${PKG_NAME}.sh >>${logfile} 2>&1
    chmod a+x /tmp/${PKG_NAME}.sh >>${logfile} 2>&1
    
    mv ${logfile} ${logfile}2
    OpenLogfile "${logfile}" "${logfile}2" "/tmp/${PKG_NAME}.sh"

    local mydir=$( dirname ${0} )
    local myfile=$( basename ${0} )
    cd ${mydir}
    mydir=$( pwd )
    cd /

    # Let's continue
    exec /tmp/${PKG_NAME}.sh stage2 ${mydir}/${myfile}
}

FatalError()
{
    if ! grep ^${device} /proc/mounts >/dev/null
    then
	# Stickdevice is'nt mounted
	echo "Mount stick back on ${mountpoint}"
	mount ${device} ${mountpoint}
    fi
    
    # Find mountpoint
    mountpoint=$( grep ^${device} /proc/mounts | cut -d ' ' -f 2 )
    [ "${mountpoint}" = "" ] && mountpoint=/tmp || mountpoint=${mountpoint}/Logs
    
    # Move logfile
    mkdir -p ${mountpoint}
    echo "+++Move ${mountpoint}/\Entware-ng.log"
    OpenLogfile -
}

Stage2()
{
    echo "Running ${0} stage2 \"$@\""
    echo "Find current device & mointpoint"

    local funplug=${1}

    mountpoint=$( dirname $( dirname ${funplug} ) )
    echo "Found mountpoint candidate ${mountpoint}"
    device=$( cat /proc/mounts | awk '{ print $2 " " $1 }' | grep "^${mountpoint} " | cut -d ' ' -f 2 )
    
    if [ "${device}" = "" ] ; then
	echo "FATAL. ${funplug} is not on a mountpoint"
	mkdir -p ${mountpoint}/Logs
	echo "+++Move ${mountpoint}/Logs/${PKG_NAME}.log"
	OpenLogfile "-"
	exit 1
    fi

    trap FatalError EXIT    
    
    echo "Device ${device} is mounted on ${mountpoint}"
    
    [ "${mountpoint}" != "/mnt/parnerkey" -a "${mountpoint}" != "/mnt/partnerkey" ] && echo "FATAL. Mountpoint is not /mnt/par(t)nerkey. Cowardly refusing to continue" && exit 1
    
    local maindevice=$( echo ${device} | sed 's|[0-9]||' ) 
    local mounted=""
    
    if [ ! -f ${mountpoint}/ForceInstall ]
    then
	echo "Check if the stick ${maindevice} has a usable ext partition"
	echo "+++Indent+"
	mkdir /opt
    
	for dev in $( cat /proc/partitions | awk '{ print "/dev/" $4 }' | grep "^${maindevice}" )
	do
	    echo "Probe ${dev}"
	    mounted="${dev}"
	    mount -t ext3 ${dev} /opt 2>/dev/null
	    [ $? -eq 0 ] && echo "Succeeded" && break
	    mount -t ext2 ${dev} /opt 2>/dev/null
	    [ $? -eq 0 ] && echo "Succeeded" && break
	    mounted=""
	    echo "Failed"
	done
	echo "+++Indent-"
    else
	echo "Found ${mountpoint}/ForceInstall"
    fi
    
    if [ "" = "$mounted" ] 
    then
	echo "Going to repartition ${maindevice}"
	echo "+++Indent+"
	    [ -d /opt ] && rmdir /opt

	    echo "Copy files from stick"
    	    local tmpdir=/tmp/${PKG_NAME}.tmp
	    mkdir -p ${tmpdir}
	
	    for file in NSA221_check_file STG100_check_file md5sum nsa210_check_file usb_key_func.sh Readme STG211_check_file 			nas3xx_check_file nsa310_check_file_C0 Resources STG212_check_file nas5xx_check_file nsa310_check_file_C0.Zy_Private
	    do
		cp -a ${mountpoint}/${file} ${tmpdir}/
	    done
        
	    umount ${mountpoint}
	    [ $? -ne 0 ] && echo "FATAL. Cannot unmount ${device}" && exit 1

	    sync

	    echo "fdisk:"
	    echo "+++Indent+"
	
		    echo -e "o\nn\np\n1\n\n+16M\nn\np\n2\n\n\nt\n1\n4\nw\n" | fdisk ${maindevice}
    		    [ $? -ne 0 ] && echo "FATAL. Repartitioning failed" && exit 1
	
		    sync
	
	    echo "+++Indent-"
	
	echo "+++Indent-"
	
	echo "Create fat system on partition ${maindevice}1"
	echo "+++Indent+"
	    ln -s ${tmpdir}/md5sum /tmp/mkdosfs
	    /tmp/mkdosfs -n EntwareBoot ${maindevice}1
	    [ $? -ne 0 ] && echo "FATAL. Cannot format ${maindevice}1" && exit 1
	    rm /tmp/mkdosfs
	echo "+++Indent-"
	
	echo "Mount and move files back"
	echo "+++Indent+"
	    mount ${maindevice}1 ${mountpoint}
	    [ $? -ne 0 ] && echo "FATAL. Cannot mount ${maindevice}1" && exit 1
	    
	    mv ${tmpdir}/* ${mountpoint}/
	    rmdir ${tmpdir}
	    
	echo "+++Indent-"
	
	echo "Create ext2 system on partition ${maindevice}2"
	echo "+++Indent+"
	    ln -s ${mountpoint}/md5sum /tmp/mke2fs
	    /tmp/mke2fs -L EntwareRoot ${maindevice}2
	    [ $? -ne 0 ] && echo "FATAL. Cannot format ${maindevice}2" && exit 1
	    rm /tmp/mke2fs
	echo "+++Indent-"

	echo "Mount on /opt"
	echo "+++Indent+"
	    mkdir -p /opt
	    mount ${maindevice}2 /opt
	    [ $? -ne 0 ] && echo "FATAL. Cannot mount ${maindevice}2" && exit 1
	    
	    echo Create a bunch of symlinks
	    local bunchdir=/opt/.BunchOfSymlinks
	    mkdir -p ${bunchdir}
	    
    	    cat >${bunchdir}/readme <<__EOS__
In at least on firmware version zyshd runs 
"rm \` find /mountpoint/of/stick -type l \`" 
after mounting any external device.
This removes all symlinks from the device, rendering ${PKG_NAME} useless.
The bunch of symlinks here are added to overflow the commandline,
making rm fail with an "Argument list too long" instead of deleting all symlinks
__EOS__
	    # Generate long name (128 characters)
	    longname=LongName
	    for c in 1 2 3 4
	    do
	        longname=${longname}${longname}
	    done
					            
            # Generate 6002 symlinks (total filename length > 64k)
	    counter=0
	    for a in 0 1 2 3 4 5
	    do
		for b in 0 1 2 3 4 5 6 7 8 9 
		do
		    for c in 0 1 2 3 4 5 6 7 8 9
		    do
	                ln -s "readme" ${bunchdir}/${a}${b}${c}${longname}
		    done
		done
	    done
	    longname="" #Don't know if this actually free's up anything
	echo "+++Indent-"
    
    else
	echo "Unmount and remount ${device}"
	# The Medion has a readonly mounted stick
	echo "+++Indent+"
	    umount ${device} 
	    mount ${device} ${mountpoint}
	echo "+++Indent-"
    
    fi
    
    mkdir -p ${mountpoint}/Logs
    echo "+++Move ${mountpoint}/Logs/${PKG_NAME}.log"

    trap "" EXIT
    
    local starter=/opt/etc/init.d/rc.unslung
    
    if [ ! -x ${starter} ] ; then
	echo "Entware is not installed yet. Deferring procedure until we have network"
	OpenLogfile "-"
	${0} stage3 ${device} &
	sleep 1
	exit 1
    fi
	
    if [ "$MOUNT_TIMEOUT" -eq "$MOUNT_TIMEOUT" -a $MOUNT_TIMEOUT -gt 0 ] ; then
	echo "Deferring starting of Entware until the harddisk(s) is mounted"
	OpenLogfile "-"
	${0} stage3a ${device} &
	sleep 1
	exit 1
    fi
    
    FinalStart
    exit 1
}
    
Stage3a()
{
	OpenLogfile "/tmp/${PKG_NAME}.log.tmp" "" "${0}"

        echo "Running ${0} stage3a \"$@\""
	device=${1}
	
	local succeeded=0
	local counter=0
	echo "Start polling for the mount of the harddisk(s)"
	while [ $counter -lt ${MOUNT_TIMEOUT} ] 
	do
	    sleep 10
	    if grep "/i-data/" /proc/mounts >/dev/null
	    then
		    succeeded=1
		    counter=${MOUNT_TIMEOUT}
		    continue
	    fi
	    let counter=counter+10
	done
	
	[ $succeeded -eq 0 ] && echo "Timeout on mounting of the harddisk" || echo "Harddisk(s) are mounted"
	sleep 10
	
	# Have a look if the FAT partition is already mounted
        local mountpoint=$( grep "^${device}" /proc/mounts | cut -d ' ' -f 2 )
        case "${mountpoint}" in
		"/e-data/"*)
		    succeeded=1
		    ;;
		*)
		    mountpoint="/e-data/"Entware-ng
		    mkdir -p ${mountpoint}
		    mount ${device} ${mountpoint} -o umask=0
		    ;;
	esac

	# Add to logfile
	echo "+++Append ${mountpoint}/Logs/${PKG_NAME}.log"

        FinalStart

	exit 0
}
	

Stage3()
{
	OpenLogfile "/tmp/${PKG_NAME}.log.tmp" "" "${0}"

        echo "Running ${0} stage3 \"$@\""
	device=${1}

	# Start polling for the existence of pkg.entware.net
	echo "Start polling for the reachability of pkg.entware.net"
	echo "+++Indent+"
	local succeeded=0
	while [ $succeeded -lt 3 ] 
	do
	    sleep 10
	    ping -c 1 pkg.entware.net 2>&1 >/dev/null
	    [ $? -eq 0 ] && let succeeded=succeeded+1 || succeeded=0
	done
	echo "OK. Internet is up"
	# Now internet is up, so continue
	echo "+++Indent-"
	
	# Find current kernel version
	IsOldKernel
	[ $? -eq 0 ] && PKG_OLDKERNEL=1 && echo "Old kernel (<2.6.32) detected"

	echo "+++Indent+"
	chmod 755 /opt
	Install
	if [ $? -ne 0 ] ; then
	    OpenLogfile -
	    exit 1
	fi
	echo "+++Indent-"

	local loginless=/opt/etc/init.d/S95LoginlessTelnet

	cat >${loginless} <<__EOS__
#!/bin/sh

if [ "\$1" = "start" ] ; then
    telnetd -l /bin/sh
fi

if [ "\$1" = "stop" ] ; then
    for pid in \$( pidof telnetd )
    do
	if grep /bin/sh /proc/\${pid}/cmdline >/dev/null
	then
	    kill \${pid}
	fi
    done
fi
__EOS__
	chmod +x ${loginless}

	SayHello

	FinalStart
}

FinalStart()
{
	[ -x /opt/sbin/kernel-2.6.24-support.sh ] && /opt/sbin/kernel-2.6.24-support.sh
	local start="/opt/etc/init.d/rc.unslung start"
	echo "Run ${start}"
	echo "+++Indent+"
	${start}	
	echo "+++Indent-"
	echo "Done ${start}"

	local rcs=/etc/init.d/rc.shutdown
	
	echo "Inject exit code in ${rcs}"
	echo "+++Indent+"
		sed -i "2i[ -x /opt/etc/init.d/rc.unslung ] && /opt/etc/init.d/rc.unslung stop" ${rcs}
		sed -i "3imountpoint /opt && umount /opt" ${rcs}
	echo "+++Indent-"
	echo Inject done
	
    	OpenLogfile -
	rm $0
}

StickMain1()
{
    local command=$1
    shift

    case "$command" in
	stage1)
	    Stage1 "$@"
	    ;;
	stage2)
	    Stage2 "$@"
	    ;;
	stage3)
	    Stage3 "$@"
	    ;;
	stage3a)
	    Stage3a "$@"
	    ;;
	filter)
	    FilterLogfile "$@"
	    ;;
	*)
	    echo "This script is for internal use of the ${PKG_NAME} stick"
	    ;;    
    esac	
}

StickMain()
{
       IsOldKernel
        [ $? -eq 0 ] && PKG_OLDKERNEL=1 && echo "Old kernel (<2.6.32) detected"

        echo "+++Indent+"
        chmod 755 /opt
        Install
}

StickMain

