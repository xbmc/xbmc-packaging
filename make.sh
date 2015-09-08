#!/bin/bash

# generates kodi packaging for selected flavors
# this is required to properly define build-depends and file lists

usage() {
	echo "Usage: $0 <fb|x11> <gl|gles> <generic|imx>"
}

function generate_packaging() {
	# arguments: <ws> <gl> <target>

	# define constants
	__KODI_WS_FB=0
	__KODI_WS_X11=1

	__KODI_GL_GL=0
	__KODI_GL_GLES=1

	__KODI_TARGET_GENERIC=0
	__KODI_TARGET_IMX=1

	ws=x11 && test "$#" -ge 1 && ws="$1"
	test "x$ws" != "xfb" -a "x$ws" != "xx11" && echo "unknown backend \"$ws\"" && return 1
	test "x$ws" = "xfb" && KODI_WS=$__KODI_WS_FB
	test "x$ws" = "xx11" && KODI_WS=$__KODI_WS_X11

	gl=gl && test "$#" -ge 2 && gl="$2"
	test "x$gl" != "xgl" -a "x$gl" != "xgles" && echo "unknown gl variant \"$gl\"" && return 1
	test "x$gl" = "xgl" && KODI_GL=$__KODI_GL_GL
	test "x$gl" = "xgles" && KODI_GL=$__KODI_GL_GLES

	tg=generic && test "$#" -ge 3 && tg="$3"
	test "x$tg" != "xgeneric" -a "x$tg" != "ximx" && echo "unknown target \"$tg\"" && return 1
	test "x$tg" = "xgeneric" && KODI_TARGET=$__KODI_TARGET_GENERIC
	test "x$tg" = "ximx" && KODI_TARGET=$__KODI_TARGET_IMX

	# write kodiconfig.inc
	rm -f kodiconfig.inc
	for var in __KODI_WS_FB __KODI_WS_X11 KODI_WS \
		__KODI_GL_GL __KODI_GL_GLES KODI_GL \
		__KODI_TARGET_GENERIC __KODI_TARGET_IMX KODI_TARGET; do
		cmd=`printf 'val=$%s' $var`
		eval $cmd
		echo "#define $var $val" >> kodiconfig.inc
	done

	# create build directory
	rm -rf build
	mkdir -v build

	# create directories
	find debian -type d -exec mkdir build/{} \;

	# copy files
	files=`find debian -type f -print`
	for file in $files; do
		# generated file?
		if [[ $file == *.in ]]; then
			name=`basename $file .in`
			dir=`dirname $file`
			./format.sh $file build/$dir/$name
			sed -i build/$dir/$name \
				-e "s;@KODI_WS@;$ws;g" \
				-e "s;@KODI_GL@;$gl;g" \
				-e "s;@KODI_TARGET@;$tg;g"
			echo "GEN $dir/$name"
		else
			# just copy it
			cp $file build/$file
			echo "CP  $file"
		fi
	done

	# create debian source package
	srcversion=`head -1 debian/changelog | sed -e "s;.*(;;g" -e "s;).*;;g" -e "s;.*:;;g" | cut -d'-' -f1`
	pkgversion=`head -1 debian/changelog | sed -e "s;.*(;;g" -e "s;).*;;g" -e "s;.*:;;g"`

	# source tarball required
	if [ ! -e kodi_$srcversion.orig.tar.gz ] && [ ! -e kodi_$srcversion.orig.tar.xz ]; then
		echo "Not building source package because kodi_$srcversion.orig.tar.{gz,xz} is missing!"
		return 0
	fi

	# TODO: extract source tarball in build to stop dpkg-source warnings?

	# call dpkg-source to do the hard work
	dpkg-source -b build

	return 0
}

s=0
if [ $# -gt 3 ]; then
	s=1
fi
if [ $# -eq 3 ]; then
	generate_packaging $1 $2 $3 || s=$?
fi
if [ $# -eq 2 ]; then
	generate_packaging $1 $2 || s=$?
fi
if [ $# -eq 1 ]; then
	generate_packaging $1 || s=$?
fi
if [ $# -eq 0 ]; then
	generate_packaging || s=$?
fi
if [ $s -ne 0 ]; then
	usage
fi
exit $s
