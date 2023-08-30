#!/bin/sh

echo shutdown: "$@"

wdt="-t 1 -T 5"
wdrst="-T 150"

export PS1="shutdown-sh# "
# exec bin/sh

cd /
if [ ! -e /proc/mounts ]
then
	mkdir -p /proc
	mount  proc /proc -tproc
	umount_proc=1
else
	umount_proc=
fi

# for the log, how was init setup and what was left mounted
cat /init-options /proc/mounts

# Remove an empty oldroot, that means we are not invoked from systemd-shutdown
rmdir /oldroot 2>/dev/null

# Move /oldroot/run to /mnt in case it has the underlying rofs loop mounted.
# Ordered before /oldroot the overlay is unmounted before the loop mount
# Unmount under initramfs but not the initramfs directory itself
# Also unmount /ro and /rw if they are mounted (/run/initramfs/{ro,rw} before pivot)
mkdir -p /mnt
mount --move /oldroot/run /mnt

script='/oldroot|mnt/ { print $2 }'
#script='/oldroot|mnt|initramfs/ { print $2 }'
#script='/oldroot|mnt|initramfs[^ ]/ { print $2 }'
#script="$script"' / .r[ow] / { print $2 }'
scriptfile=/shutdown-filter.awk
test -f $scriptfile || echo "$script" > $scriptfile
cat $scriptfile
set -x
awk -f $scriptfile < /proc/mounts |
	sort -r | while IFS= read -r f
do
	umount "$f"
done
set +x

# If we mounted a separate filesystem at /run/initramfs then its now
# root and not at the original /run/initramfs.   Re-establish to
# run the update script in it's expected enviornment.
api=/run/initramfs
update=$api/update
image=$api/image-

if [ ! -f $api/shutdown ]
then
	mkdir -p $api
	mount --bind / $api
fi

if ls $image* > /dev/null 2>&1
then
	if test -x $update
	then
		if test -c /dev/watchdog
		then
			echo Pinging watchdog ${wdt+with args $wdt}
			# shellcheck disable=SC2086
			watchdog $wdt -F /dev/watchdog &
			wd=$!
		else
			wd=
		fi
		$update --clean-saved-files
		remaining=$(ls $image*)
		if test -n "$remaining"
		then
			echo 1>&2 "Flash update failed to flash these images:"
			echo 1>&2 "$remaining"
		else
			echo "Flash update completed."
		fi

		if test -n "$wd"
		then
			kill -9 $wd
			if test -n "$wdrst"
			then
				echo "Resetting watchdog timeouts to $wdrst"
				# shellcheck disable=SC2086
				watchdog $wdrst -F /dev/watchdog &
				sleep 1
				# Kill the watchdog daemon, setting a timeout
				# for the remaining shutdown work
				kill -9 $!
			fi
		fi
	else
		echo 1>&2 "Flash update requested but $update program missing!"
	fi
fi

echo Remaining mounts:
cat /proc/mounts

test "$umount_proc" && umount /proc && rmdir /proc

export PS1="pending-$1# "
exec /bin/sh

# tcsattr(tty, TIOCDRAIN, mode) to drain tty messages to console
test -t 1 && stty cooked 0<&1

# Execute the command systemd told us to ...
if test -d /oldroot  && test "$1"
then
	if test "$1" = kexec
	then
		$1 -f -e
	else
		$1 -f
	fi
fi


echo "Execute ${1-reboot} -f if all unmounted ok, or exec /init"

export PS1=shutdown-sh#\
exec /bin/sh


# musings to preserve /run/initramfs before switch_root damage
copy=/run/mnt/initramfs
mkdir -p $copy
mount -t tmpfs initrd $copy
cp -rp $api $copy
for f in "proc sys dev run"
do
	mount --bind $f $copy
done
pivot_root $copy $copy/$copy
