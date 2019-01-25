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

	mkdir -p "$SRVDIR"
	echo "$STATUS" > "$SRVDIR/status"

	# illegal PID?
	if [[ $STATUS -eq 127 ]]; then
		exit
	fi

	# WIFEXITED(STATUS)
	if [[ $((STATUS & 0x7f)) -eq 0 ]]; then
		ACTUAL=$(( (STATUS & 0xff00) >> 8 ))
		echo "Exit-Status: $ACTUAL"
		if [[ $RESTART != RESTART ]] || [[ $ACTUAL -eq 0 ]]; then
			exit
		fi
	# WIFSIGNALED(STATUS)
	elif [[ $(( ( (STATUS & 0x7f) + 1) >> 1 )) -gt 0 ]]; then
		SIGNAL=$(( STATUS & 0x7f ))
		echo "Exit-Signal: $SIGNAL"
		if [[ $RESTART != RESTART ]] || [[ $SIGNAL -eq 15 ]] || [[ $SIGNAL -eq 9 ]]; then
			exit
		fi
	else
		echo "Unhandled-Exit-State: $STATUS"
		exit
	fi
done
