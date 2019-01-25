#!/bin/bash

set -e

SRVDIR=$1
RESTART=$2
shift 2

while [ : ]; do
	nohup "$@" 2>&1 &
	PID=$!

	mkdir -p "$SRVDIR"
	echo "$PID" > "$SRVDIR/pid"

	set +e
	wait "$PID" 2>/dev/null
	STATUS=$?

	rm "$SRVDIR/pid" 2>/dev/null
	set -e

	echo
	echo "Exit-Status: $STATUS"

	mkdir -p "$SRVDIR"
	echo "$STATUS" > "$SRVDIR/status"

	# WIFEXITED(STATUS)
	if [[ $((STATUS & 0x7f)) -eq 0 ]]; then
		STATUS=$(( (STATUS & 0xff00) >> 8 ))
		echo "Exit-Status: $STATUS"
		if [[ $RESTART != RESTART ]] || [[ $STATUS -eq 0 ]]; then
			exit
		fi
	fi
	
	# WIFSIGNALED(STATUS)
	if [[ $(( ( (STATUS & 0x7f) + 1) >> 1 )) -gt 0 ]]; then
		SIGNAL=$(( STATUS & 0x7f ))
		echo "Exit-Signal: $SIGNAL"
		exit
	fi

	if [[ $STATUS -eq 127 ]]; then
		# illegal PID
		exit
	fi
done
