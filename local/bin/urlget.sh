#!/bin/bash

#debug=false
debug=true

set +b

showhelp() {
cat << EOF
Usage: $0 -u URL -o FILE -d NUM
  -u URL   specify URL to capture
  -o FILE  specify image file (should be .png)
  -ua 'USER_AGENT'  customize the user agent
  -p 'host:port'  customize the proxy
  -d NUM   total wait time in seconds (defaults to 15)
  -od NUM  optimized delay time in seconds
            (defaults to infinite)
EOF
}

err() {
	echo -e "$0: $2"
	exit $1
}

older_filetime() {
    FILE_TIME=`stat --format=%Y ${1}`
    MY_TIME=`date --date="-${2} seconds" +%s`

    [ ${FILE_TIME} -le ${MY_TIME} ] && echo true
}

manage_lock() {
    lockfile="${1}"
    timeout="${2}"
	errlevel="${3}"

	${debug} && echo "manage_lock('${1}',${2},${3})"
    if [ -f ${lockfile} ]; then
        echo "already running"

        if [ ! "`older_filetime ${lockfile} ${timeout}`" = "true" ]; then
            err ${errlevel} "lock file in place"
        else
            echo "${product} unlocked on `date`"
        fi
    fi

    touch ${lockfile}
}

end() {
	manage_lock /var/run/screencapt/saving-${DISPLAY}_${parent_pid} 100 0

	[[ -n "${odelay_pid}" ]] && {
		${debug} && echo "end() terminating ${delay_pid} ${odelay_pid}"
		kill ${delay_pid} ${odelay_pid}
	}

	import -window root "${out}"
	kill ${ffox_pid}

	if [ -z "${proxy}" ]; then
		strings "${out}.wrapper" | grep -E '(SENT GET)|(Host)'  | sed -e :a -e '$!N;s/\nHost:/ /;ta' -e 'P;D' | sed 's|.*[0-9]\{4\}: SENT GET \(.*\) HTTP/.* \(.*\)|http://\2\1|' > "${out}.urls"
	else
		strings "${out}.wrapper" | grep 'SENT GET' | sed 's|.*[0-9]\{4\}: SENT GET \(.*\) HTTP/.*|\1|' > "${out}.urls"
	fi

	rm -f /var/run/screencapt/lock-${DISPLAY}
	rm -f /var/run/screencapt/saving-${DISPLAY}_${parent_pid}
	rm -f "${out}.wrapper"

	# ugly
	[[ -n "${odelay_pid}" ]] && killall sleep

	echo "execution time $((`date +%s` - ${t_start}))s"
	exit 0
}

watchlog() {
	while true; do
		[[ ! -f "${out}.wrapper" ]] && {
			${debug} && echo "watchlog() no transfer has been performed yet, sleeping"
			sleep 1
			continue
		}
		s=$(stat --format='%Y' "${out}.wrapper")
		sleep "${odelay}"
		s2=$(stat --format='%Y' "${out}.wrapper")
		${debug} && echo "watchlog() ${s} ${s2}"
		[[ "${s}" == "${s2}" ]] && {
			${debug} && echo "watchlog() odelay triggered, signaling ${parent_pid}"
			kill -HUP ${parent_pid}
		}
	done
}

delay() {
	sleep "${delay}"
	${debug} && echo "delay() delay triggered, signaling ${parent_pid}"
	kill -HUP ${parent_pid}
}

remove_user_agent() {
	sed -i '/.*general.useragent.override.*/d' /home/capt/.mozilla/firefox/6u2jq4c7.default/prefs.js
}

set_user_agent() {
	remove_user_agent
	echo "user_pref(\"general.useragent.override\", \"$@\");" >> /home/capt/.mozilla/firefox/6u2jq4c7.default/prefs.js
}

set_proxy() {

	proxy_host=${1%:*}
	proxy_port=${1#*:}

cat << EOF >> /home/capt/.mozilla/firefox/6u2jq4c7.default/prefs.js
user_pref("network.proxy.ftp", "${proxy_host}");
user_pref("network.proxy.ftp_port", ${proxy_port});
user_pref("network.proxy.http", "${proxy_host}");
user_pref("network.proxy.http_port", ${proxy_port});
user_pref("network.proxy.share_proxy_settings", true);
user_pref("network.proxy.socks", "${proxy_host}");
user_pref("network.proxy.socks_port", ${proxy_port});
user_pref("network.proxy.ssl", "${proxy_host}");
user_pref("network.proxy.ssl_port", ${proxy_port});
user_pref("network.proxy.type", 1);
EOF
}

if [ $# -lt 4 ]; then
        showhelp
        exit 1
fi

t_start=$(date +%s)

export DISPLAY=':1'
export parent_pid=$$
manage_lock /var/run/screencapt/lock-${DISPLAY} 100 1


while (( "$#" )); do
        if [ "$1" = "-u" ]; then
                url="${2}"
                shift
                shift
        elif [ "$1" = "-o" ]; then
                out="${2}"
                shift
                shift
        elif [ "$1" = "-ua" ]; then
                ua="${2}"
                shift
                shift
        elif [ "$1" = "-p" ]; then
                proxy="${2}"
                shift
                shift
        elif [ "$1" = "-d" ]; then
                delay="${2}"
                shift
                shift
        elif [ "$1" = "-od" ]; then
                odelay="${2}"
                shift
                shift
        elif [ "$1" = "-h" ]; then
                showhelp
                shift
        else 
                echo "warning: '$1' is an unknown command"
                shift
        fi
done

trap 'end' SIGHUP

rsync -a --delete --exclude ".vnc/*.log" /home/capt_clean/ /home/capt/

if [ -z "${ua}" ]; then
	remove_user_agent
else
	set_user_agent "${ua}"
fi

if [ ! -z "${proxy}" ]; then
	set_proxy "${proxy}"
fi

rm -f "${out}.wrapper"
export WRAPPER_LOG="${out}.wrapper"
export LD_PRELOAD=libsend.so

/usr/bin/firefox --display=${DISPLAY} "${url}" &>/dev/null &
ffox_pid=$!

# optimized delay fork
[[ -n "${odelay}" ]] && {
	[[ ${delay} -gt ${odelay} ]] && {
		watchlog &
		odelay_pid=$!
	}
}

# by default the main process ends after ${delay} seconds
delay &
delay_pid=$!

${debug} && echo "main() parent_pid=${parent_pid} ffox_pid=${ffox_pid} delay_pid=${delay_pid} odelay_pid=${odelay_pid}"

wait


