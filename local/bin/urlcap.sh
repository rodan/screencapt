#!/bin/bash

delay=15
verify_mime_type='image/png'
verify_min_size='30000'

showhelp() {
cat << EOF
Usage: $0 -u "URL" -o "FILE" -d NUM
  -u URL   specify URL to capture
  -ua 'user agent'   customize the user agent
  -p 'host:port'  proxy:port
  -o FILE  specify image file (should be .png)
  -l FILE  specify filename for the logfile 
            containing the URLs visited by firefox
  -d  NUM  total wait time in seconds (defaults to 15)
  -od NUM  optimized delay (default infinite)
            must be less then the value of -d
  -v       run verification routine on the output file
EOF
}

err() {
	echo -e "$0: $2"
	exit $1
}

if [ $# -lt 4 ]; then
	showhelp
	exit 1
fi

verify=false

extra=''

while (( "$#" )); do
	if [ "$1" = "-u" ]; then
		url="${2}"
		shift
		shift
	elif [ "$1" = "-ua" ]; then
		extra="${extra} -ua '${2}'"
		shift
		shift
	elif [ "$1" = "-p" ]; then
		extra="${extra} -p '${2}'"
		shift
		shift
	elif [ "$1" = "-o" ]; then
		out="${2}"
		shift
		shift
	elif [ "$1" = "-l" ]; then
		lout="${2}"
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
	elif [ "$1" = "-v" ]; then
		verify=true
		shift
	elif [ "$1" = "-h" ]; then
		showhelp
		shift
	else 
		echo "warning: '$1' is an unknown command"
		shift
	fi
done


[[ -z "${url}" ]] && err 1 "mandatory '-u "URL"' has not been specified"
[[ -z "${out}" ]] && err 1 "mandatory '-o "FILE"' has not been specified"
[[ -f "${out}" ]] && err 1 "output image file already exists"
[[ -f "${lout}" ]] && err 1 "output log file already exists"
[[ -n "${odelay}" ]] && extra="${extra} -od ${odelay}"

tmp_out="/tmp/screencapt/`basename ${out}`"


ssh -i /home/webadmin/.ssh/screencapt_rsa -p 40022 capt@127.0.0.1 \
	/local/bin/urlget.sh -u \'"${url}"\' -o \'"${tmp_out}"\' -d "${delay}" "${extra}"
[[ "$?" != "0" ]] && err 1 "remote ssh command has failed"

mv -f "/local/screencapt/${tmp_out}" "${out}"
[[ "$?" != "0" ]] && err 1 "image file move has failed" 

mv -f "/local/screencapt/${tmp_out}.urls" "${lout}"
[[ "$?" != "0" ]] && err 1 "logfile move has failed" 

[[ -f "${out}" ]] || err 1 "output file has not been generated"

${verify} && {

	mime_type=$(file --brief --mime-type "${out}")
	file_size=$(stat --format='%s' "${out}")

	[[ "${file_size}" -lt "${verify_min_size}" ]] && \
		err 1 "file is less than ${verify_min_size} bytes long"

	echo "${mime_type}" | grep -q "${verify_mime_type}" || \
		err 1 "output file has the wrong mime type\n'${mime_type}'!='${verify_mime_type}'"
}

exit 0

