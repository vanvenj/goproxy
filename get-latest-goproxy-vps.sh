#!/bin/bash

set -e

linkpath=$(ls -l "$0" 2>/dev/null | sed "s/.*->\s*//")
cd "$(dirname "$0")" && test -f "$linkpath" && cd "$(dirname "$linkpath")" || true

FILENAME_PREFIX=
case $(uname -s)/$(uname -m) in
	Linux/x86_64 )
		FILENAME_PREFIX=goproxy-vps_linux_amd64
		;;
	Linux/i686|Linux/i386 )
		FILENAME_PREFIX=goproxy-vps_linux_386
		;;
	Linux/aarch64|Linux/arm64 )
		FILENAME_PREFIX=goproxy-vps_linux_arm64
		;;
	Linux/arm* )
		FILENAME_PREFIX=goproxy-vps_linux_arm
		if grep -q ld-linux-armhf.so ./goproxy; then
			FILENAME_PREFIX=goproxy-vps_linux_arm_cgo
		fi
		;;
	Linux/mips64el )
		FILENAME_PREFIX=goproxy-vps_linux_mips64le
		;;
	Linux/mips64 )
		FILENAME_PREFIX=goproxy-vps_linux_mips64
		;;
	Linux/mipsel )
		FILENAME_PREFIX=goproxy-vps_linux_mipsle
		;;
	Linux/mips )
		FILENAME_PREFIX=goproxy-vps_linux_mips
		;;
	FreeBSD/x86_64 )
		FILENAME_PREFIX=goproxy-vps_freebsd_amd64
		;;
	FreeBSD/i686|FreeBSD/i386 )
		FILENAME_PREFIX=goproxy-vps_freebsd_386
		;;
	Darwin/x86_64 )
		FILENAME_PREFIX=goproxy-vps_macos_amd64
		;;
	Darwin/i686|Darwin/i386 )
		FILENAME_PREFIX=goproxy-vps_macos_386
		;;
	* )
		echo "Unsupported platform: $(uname -a)"
		exit 1
		;;
esac

LOCALVERSION=$(./goproxy-vps -version 2>/dev/null || :)
echo "0. Local Goproxy VPS version ${LOCALVERSION}"

echo "1. Checking GoProxy VPS Version"
curl -L https://github.com/phuslu/goproxy-ci/commits/master >goproxy-ci.txt
MAJORVERSION=$(cat goproxy-ci.txt | grep -oE "goproxy_linux_amd64-r[0-9]+.[0-9a-z\.]+" | head -1 | awk -F'.' '{print $1}' | awk -F'-' '{print $2}')
FILENAME=$(cat goproxy-ci.txt | grep -oE "${FILENAME_PREFIX}-r[0-9]+.[0-9a-z\.]+" | head -1)
REMOTEVERSION=$(echo ${FILENAME} | awk -F'.' '{print $1}' | awk -F'-' '{print $3}')
rm -rf goproxy-ci.txt
if test -z "${REMOTEVERSION}"; then
	echo "Cannot detect ${FILENAME_PREFIX} version"
	exit 1
fi

if [[ ${LOCALVERSION#r*} -ge ${REMOTEVERSION#r*} ]]; then
	echo "Your GoProxy already update to latest"
	exit 1
fi

echo "2. Downloading ${FILENAME}"
curl -kL https://github.com/phuslu/goproxy-ci/releases/download/${MAJORVERSION}/${FILENAME} >${FILENAME}.tmp
mv -f ${FILENAME}.tmp ${FILENAME}

echo "3. Extracting ${FILENAME}"
rm -rf ${FILENAME%.*}
case ${FILENAME##*.} in
	xz )
		xz -d ${FILENAME}
		;;
	bz2 )
		bzip2 -d ${FILENAME}
		;;
	gz )
		gzip -d ${FILENAME}
		;;
	* )
		echo "Unsupported archive format: ${FILENAME}"
		exit 1
esac

tar -xvpf ${FILENAME%.*} --strip-components $(tar -tf ${FILENAME%.*} | head -1 | grep -c '/')
rm -f ${FILENAME%.*}

echo "4. Configure goproxy-vps"

if [ ! -f acme_domain.txt ]; then
	read -p "Please input your domain: " acme_domain </dev/tty
	if test -n "${acme_domain}"; then
		echo ${acme_domain} >acme_domain.txt
	fi
fi

if [ ! -f extra-args.txt ]; then
	read -p "Enable PAM Auth for goproxy-vps? [y/N]:" pwauth </dev/tty
	if test "${pwauth}" = "y"; then
		echo "-pwauth" >extra-args.txt
	fi
fi

echo "5. Done"
echo
echo "Please run \"sudo $(pwd)/goproxy-vps.sh start\""
