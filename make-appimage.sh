#!/bin/sh

set -e

# CI containers often run as root which prevents some apps from working
export ELECTRON_DISABLE_SANDBOX=1
export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
export QTWEBENGINE_DISABLE_SANDBOX=1
export $(dbus-launch 2>/dev/null || echo 'NO_DBUS=1')
export USER="${LOGNAME:-${USER:-${USERNAME:-yomama}}}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"

ARCH=$(uname -m)

squashfs_runtime=$(command -v uruntime-appimage-squashfs-lite-"$ARCH")
dwarfs_runtime=$(command -v uruntime-appimage-dwarfs-lite-"$ARCH")

mkdir -p ./AppImages
cd ./AppImages

set -- \
	https://github.com/pkgforge-dev/CollaboraOffice-AppImage/releases/download/25.04.9.2-1%402026-05-01_1777639060/Collabora_Office-25.04.9.2-1-anylinux-"$ARCH".AppImage

for appimage do
	wget "$appimage"
done

chmod +x ./*.AppImage

for artifact in ./*.AppImage; do
	rm -rf ./AppDir ./squashfs-root ./squashfs
	"$artifact" --appimage-extract

	# squashfs
	mksquashfs ./AppDir ./squashfs -comp zstd -Xcompression-level 22 -b 1M
	cp -v "$squashfs_runtime" ./"${artifact%%-*}"-SQUASHFS.AppImage
	cat ./squashfs >> ./"${artifact%%-*}"-SQUASHFS.AppImage

	# now dwarfs
	appimagetool --name ./"${artifact%%-*}"-DWARFS.AppImage "$PWD"/AppDir
	OPTIMIZE_LAUNCH=1 appimagetool --name ./"${artifact%%-*}"-optimized-DWARFS.AppImage "$PWD"/AppDir

	chmod +x ./*.AppImage
done

/usr/bin/i3 &
sleep 3
mkdir -p /tmp/test
mv -v ./*-DWARFS.AppImage    /tmp/test
mv -v ./*-SQUASHFS.AppImage  /tmp/test

cd /tmp/test
set -- ./*.AppImage
for appimage do
	count=0
	echo "------------------------------------------------------------"
	while [ "$count" -lt 3 ]; do
		echo 3 > /proc/sys/vm/drop_caches
		sleep 6
		echo "TESTING: $appimage - $(du -h "$appimage")"
		bench-launch "$appimage"
		count=$(( count + 1 ))
		echo "===================="
	done
	echo "------------------------------------------------------------"
done

mkdir -p /tmp/dist
mv -v ./*.AppImage /tmp/dist
