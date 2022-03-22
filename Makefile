export MACHINE = blackparrot

IMAGES_DIR = build/tmp/deploy/images/blackparrot

yocto.riscv: .toolchain_check work/flash.o work/fw_payload.o final_link.T
	riscv64-unknown-linux-gnu-ld -T final_link.T work/flash.o work/fw_payload.o -o yocto.riscv

.toolchain_check:
	riscv64-unknown-linux-gnu-objcopy --version > .toolchain_check

run_dromajo: yocto.riscv
	dromajo --host --enable_amo yocto.riscv

work/flash.o: ${IMAGES_DIR}/core-image-full-cmdline-blackparrot.ext4
	riscv64-unknown-linux-gnu-objcopy --input-target binary --output-target riscv64-unknown-linux-gnu ${IMAGES_DIR}/core-image-full-cmdline-blackparrot.ext4 work/flash.o

work/fw_payload.o: ${IMAGES_DIR}/fw_payload.bin
	riscv64-unknown-linux-gnu-objcopy --input-target binary --output-target riscv64-unknown-linux-gnu ${IMAGES_DIR}/fw_payload.bin work/fw_payload.o

${IMAGES_DIR}/core-image-full-cmdline-blackparrot.ext4 ${IMAGES_DIR}/fw_payload.bin: poky/scripts/tar build/conf/bblayers.conf
	source poky/oe-init-build-env; ulimit -u 32768; bitbake core-image-full-cmdline

build/conf/bblayers.conf:
	source poky/oe-init-build-env; bitbake-layers add-layer ../meta-linux-mainline; bitbake-layers add-layer ../bp-yocto-layer

poky/scripts/tar: work/build/tar/src/tar
	cp work/build/tar/src/tar poky/scripts/tar

work/build/tar/src/tar: work/build/tar/Makefile
	mkdir -p $(@D)
	make -C work/build/tar/

work/tar-1.34.tar.xz:
	mkdir -p $(@D)
	wget https://ftp.gnu.org/gnu/tar/tar-1.34.tar.xz -O work/tar-1.34.tar.xz

work/tar-1.34.tar: work/tar-1.34.tar.xz
	mkdir -p $(@D)
	unxz work/tar-1.34.tar.xz

work/tar-1.34/configure: work/tar-1.34.tar
	mkdir -p $(@D)
	cd work/; tar -xf tar-1.34.tar
	touch work/tar-1.34/configure

work/build/tar/Makefile: work/tar-1.34/configure
	mkdir -p $(@D)
	cd work/build/tar/; ../../tar-1.34/configure

clean:
	rm -rf build/ work/
