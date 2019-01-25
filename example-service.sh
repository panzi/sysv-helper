#!/bin/bash

SELF=`readlink -f "$0"`
PREFIX=`dirname "$SELF"`

exec ./sysv-helper.sh \
	"$1" \
	--name "example-service" \
	--restart-on-failure \
	-- \
	"$PREFIX/example-bin.sh" "some more" args
