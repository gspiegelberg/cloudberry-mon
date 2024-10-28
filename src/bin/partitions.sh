#!/bin/bash
#
# This can be improved in cases where:
#  LVM is in use
#  disk is partitioned, eg. /dev/nvme1n1p1 (253:1) is partition of /dev/nvme1n1 (253:0) where latter is reported in sar

hn=$( hostname )

df -t xfs | grep -v "Filesystem" | awk '{printf("%s %s\n",$1,$6)}' | while read device mntpt
do
	dev=$( basename $device )

	partitioned=$( echo "${dev}" | egrep "^sd|^vd|p[0-9]$" | wc -l )
	if [ $partitioned -eq 0 ]; then
		majmin=$( awk '/'${dev}'$/ {printf("%s,%s",$1,$2)}' /proc/partitions )
	else
		majmin=$( awk -v dev=$dev '{d=substr(dev, 1, length(dev)-1); if($4==d)printf("%s,%s",$1,$2)}' /proc/partitions )
	fi

	if [ -z "${majmin}" -o "${majmin}" = "," ]; then
		continue
	fi

	printf "%s,%s,%s,%s\n" "${hn}" "${device}" "${mntpt}" "${majmin}"
done


