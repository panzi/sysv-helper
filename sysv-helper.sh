#!/bin/bash

SELF=`readlink -f "$0"`
PREFIX=`dirname "$SELF"`
RESTART=NO-RESTART
MAX_WAIT=100

COMMAND=$1
shift

done=F
while [[ $# -gt 0 ]] && [[ $done = F ]]; do
	case $1 in
		--name)
			SERVICE_NAME=$2
			shift 2
			;;
		--restart-on-failure)
			shift
			RESTART=RESTART
			;;
		--max-wait)
			# in 10th of seconds, testing every 10th of second
			MAX_WAIT=$2
			shift 2
			;;
		--)
			done=T
			shift
			;;
		-*)
			echo "Error: illegal option: $1">&2
			exit 1
			;;
		*)
			done=T
			;;
	esac
done

if [[ -z $SERVICE_NAME ]]; then
	echo "Error: --name option is required">&2
	exit 1
fi

if [[ ! $SERVICE_NAME =~ ^[0-9a-zA-Z][-_0-9a-zA-Z]*$ ]]; then
	echo "Error: illegal --name: $SERVICE_NAME">&2
	exit 1
fi

if [[ ! $MAX_WAIT =~ ^[0-9]+$ ]] || [[ $MAX_WAIT -lt 1 ]]; then
	echo "Error: illegal --max-wait: $MAX_WAIT">&2
	exit 1
fi

CMD=( "$@" )
SRVDIR=/var/sysv-helper/$SERVICE_NAME
#SRVDIR=$PREFIX/var/$SERVICE_NAME

function wait_for_service_shutdown () {
	PID=`cat "$SRVDIR/pid" 2>/dev/null || echo`
	if [[ -z $PID ]]; then
		echo err_pid
	fi

	if ! kill -SIGTERM "$PID"; then
		echo err_term
	fi

	local count=0
	while kill -0 "$PID" 2>/dev/null; do
		if [[ $count -gt $MAX_WAIT ]]; then
			echo err_wait_pid
		fi
		count=$((count + 1))
		sleep 0.1
	done

	echo ok
}

function start_service () {
	PID=`cat "$SRVDIR/pid" 2>/dev/null || echo`
	if [[ ! -z $PID ]]; then
		if kill -0 "$PID"; then
			echo "Error: $SERVICE_NAME is already running!" >&2
			exit 1
		fi
	fi

	mkdir -p "$SRVDIR"
	nohup "$PREFIX/wrapper.sh" "$SRVDIR" "$RESTART" "${CMD[@]}" 2>&1 >> "$SRVDIR/log" 2>/dev/null &
}

function restart_service () {
	case $(wait_for_service_shutdown) in
		err_pid)
			;;
		err_term)
			echo "Error: Failed to send SIGTERM to $SERVICE_NAME!" >&2
			exit 1
			;;
		err_wait_pid)
			echo "Error: Took to long before the $SERVICE_NAME process dissapeared! Did it crash?" >&2
			exit 1
			;;
	esac

	mkdir -p "$SRVDIR"
	nohup "$PREFIX/wrapper.sh" "$SRVDIR" "$RESTART" "${CMD[@]}" 2>&1 >> "$SRVDIR/log" 2>/dev/null &
}

function stop_service () {
	case $(wait_for_service_shutdown) in
		err_pid)
			echo "Error: $SERVICE_NAME is not running!" >&2
			exit 1
			;;
		err_term)
			echo "Error: Failed to send SIGTERM to $SERVICE_NAME!" >&2
			exit 1
			;;
		err_wait_pid)
			echo "Error: Took to long before the $SERVICE_NAME process dissapeared! Did it crash?" >&2
			exit 1
			;;
		ok)
			echo "$SERVICE_NAME shutdown complete."
			;;
	esac
}

function kill_service () {
	case $(wait_for_service_shutdown) in
		err_pid)
			echo "Error: $SERVICE_NAME is not running!" >&2
			exit 1
			;;
		err_term)
			echo "Error: Failed to send SIGTERM to $SERVICE_NAME!" >&2
			exit 1
			;;
		err_wait_pid)
			echo "Error: $SERVICE_NAME shutdown took to long! Sending SIGKILL." >&2

			if ! kill -SIGKILL "$PID"; then
				echo "Error: Failed to send SIGKILL to $SERVICE_NAME!" >&2

				if ! kill -0 "$PID"; then
					echo "Error: $SERVICE_NAME PID ($PID) does no longer exists!" >&2
				fi
			fi
			;;
		ok)
			echo "$SERVICE_NAME shutdown complete."
			;;
	esac
}

function service_livelog () {
	if [[ ! -e $SRVDIR/log ]]; then
		mkdir -p "$SRVDIR"
		touch "$SRVDIR/log"
	fi
	tail -f "$SRVDIR/log"
}

function service_status () {
	PID=`cat "$SRVDIR/pid" 2>/dev/null || echo "N/A"`
	STATUS=`cat "$SRVDIR/status" 2>/dev/null || echo "N/A"`
	online=F

	if [[ $PID != "N/A" ]]; then
		if kill -0 "$PID"; then
			online=T
			echo "Status: online"
			echo "PID: $PID"
		else
			echo "Status: offline (pidfile exists, but no process exists)"
		fi
	else
		echo "Status: offline"
	fi

	if [[ $online != T ]]; then
		# WIFEXITED(STATUS)
		if [[ $((STATUS & 0x7f)) -eq 0 ]]; then
			ACTUAL=$(( (STATUS & 0xff00) >> 8 ))
			echo "Exit-Status: $ACTUAL"
		fi
	
		# WIFSIGNALED(STATUS)
		if [[ $(( ( (STATUS & 0x7f) + 1) >> 1 )) -gt 0 ]]; then
			SIGNAL=$(( STATUS & 0x7f ))
			echo "Exit-Signal: $SIGNAL"
		fi
	fi

	echo

	tail "$SRVDIR/log"
}

case "$COMMAND" in
	start)
		start_service
		;;
	stop)
		stop_service
		;;
	kill)
		kill_service
		;;
	restart)
		restart_service
		;;
	status)
		service_status
		;;
	livelog)
		service_livelog
		;;
	pid)
		PID=`cat "$SRVDIR/pid" 2>/dev/null || echo`
		if [[ -z $PID ]]; then
			echo "Error: service is offline">&2
			exit 1
		else
			echo "$PID"
		fi
		;;
	help)
		echo "Control script of $SERVICE_NAME"
		echo
		echo "Availabel commands:"
		echo "start      - start the service"
		echo "stop       - send SIGTERM to the service process"
		echo "kill       - send SIGTERM followed by SIGKILL"
		echo "restart    - restart the service process"
		echo "status     - show status information"
		echo "livelog    - show live updating log"
		echo "pid        - get PID of service process"
		echo "help       - show this help message"
		;;
	*)
		echo "Error: Unrecognized command: $COMMAND">&2
		exit 1
		;;
esac
