#!/bin/bash

trap exit SIGTERM

while [[ $# -gt 0 ]]; do
	echo "arg: $1"
	shift
done

count=1
while [ : ]; do
	echo "count: $count"
	count=$((count + 1))
	sleep 1
done
