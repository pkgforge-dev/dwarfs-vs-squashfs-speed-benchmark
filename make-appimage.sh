#!/bin/sh

set -e

ARCH=$(uname -m)

squashfs_runtime=$(command -v uruntime-appimage-squashfs-lite-"$ARCH")
dwarfs_runtime=$(command -v uruntime-appimage-dwarfs-lite-"$ARCH")

cd ./AppImages
for artifact in ./*.AppImage; do
	rm -rf ./AppDir ./squashfs-root ./squashfs
	"$artifact" --appimage-extract

	# squashfs
	mksquashfs ./AppDir ./squashfs -comp zstd -Xcompression-level 22 -b 1M
	cp -v "$squashfs_runtime" ./SQUASHFS.AppImage
	cat ./squashfs >> ./SQUASHFS.AppImage
	chmod +x ./SQUASHFS.AppImage
	
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

	mkdwarfs "$@" -C zstd:level=22 -S26 -B6 --output ./DWARFS.AppImage
	chmod +x ./DWARFS.AppImage
done


mkdir -p ./dist
echo "X-AppImage-Name=TEST"    >  ./dist/appinfo
echo "X-AppImage-Version=TEST" >> ./dist/appinfo
echo "X-AppImage-Arch=$ARCH"   >> ./dist/appinfo
mv -v ./*.AppImage* ./dist
