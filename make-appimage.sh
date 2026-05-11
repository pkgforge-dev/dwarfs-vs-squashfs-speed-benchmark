#!/bin/sh

set -e

ARCH=$(uname -m)

squashfs_runtime=$(command -v uruntime-appimage-squashfs-lite-"$ARCH")
dwarfs_runtime=$(command -v uruntime-appimage-dwarfs-lite-"$ARCH")

mkdir -p ./AppImages
cd ./AppImages

set -- \
	https://github.com/pkgforge-dev/Anylinux-AppImages/releases/download/demo/Qt6+dbus-demo-onlysoftware-"$ARCH".AppImage \
	https://github.com/pkgforge-dev/Anylinux-AppImages/releases/download/demo/gtk4-demo-onlysoftware-"$ARCH".AppImage \
	https://github.com/pkgforge-dev/Filelight-AppImage/releases/download/26.04.0-1%402026-05-01_1777638897/Filelight-26.04.0-1-anylinux-"$ARCH".AppImage

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
	set -- \
		--force \
		--order=path \
		--set-owner 0 \
		--set-group 0 \
		--no-history \
		--no-create-timestamp \
		--header "$dwarfs_runtime" \
		--input "$PWD"/AppDir

	mkdwarfs "$@" -C zstd:level=22 -S26 -B6 --output ./"${artifact%%-*}"-DWARFS.AppImage
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
		sleep 1
		echo "TESTING: $appimage - $(du -h "$appimage")"
		bench-launch "$appimage"
		count=$(( count + 1 ))
		echo "===================="
	done
	echo "------------------------------------------------------------"
done

