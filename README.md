# Yocto for BlackParrot

This repository contains all the glue for building a Yocto image that can be run on BlackParrot.

## Build

Should be as easy as:

1. Put `riscv64-unknown-linux-gnu-` toolchain on your `PATH` (consider `PATH=$PATH:/path/to/bp-sdk/install/bin`)
2. Run `make`.

Make sure you checkout submodules; the Makefile doesn't do it for you.

## Run

1. Make sure `dromajo` is on your `PATH`.
2. `make run_dromajo`.

## How to Bypass the Makefile for Tweaking Yocto

First, if you're on kk9, you need to do some things the Makefile takes care of for you.

1. `make work/bin/tar` and put work/bin/ on your `PATH`. The CentOS version of `tar` is too old.
2. Run `ulimit -u 32768`. This fixes a "resource temporarily unavailable" error.

Next, set up the Poky environment.

1. Have your working directory be the root of this repository (the one with `bp-yocto-layer`, `Makefile`, `poky`, and friends in it).
2. `source poky/oe-init-build-env`. This will change your working directory for you, which is a little confusing.
3. Edit `./conf/local.conf` (in the build directory that you got changed into) and set `MACHINE = "blackparrot"`. An environment variable would also work, but if you do this then you'll never be confused by having forgotten to set the environment variable.
4. Make sure the bitbake layers are set up. `make build/conf/bblayers.conf` will do this for you.
5. You're now good to go and can use bitbake directly.

Some useful things to do with bitbake:
- `bitbake core-image-minimal`, to build a somewhat leaner image.
- `bitbake -c cleansstate <package>` (clean-s-state, not clean-state), which is the equivalent of `make clean`'ing a particular package.
- `bitbake linux-stable` to build just the kernel.
- `bitbake opensbi` to build just OpenSBI.

## Paths to Know

- `build/conf/local.conf` - Configuration for your current build. It's helpful to set `MACHINE = blackparrot` in here.
- `build/conf/bblayers.conf` - Specifies which layers affect the current build. It's important to have `bp-yocto-layer` as well as `meta-linux-mainline` in here. You can manipulate this with the `bitbake-layers` command.
- `build/tmp/deploy/images/blackparrot` - This is where the build artifacts go. This is the Good Stuff that you probably want.
- `build/tmp/work/blackparrot-poky-linux/*/` - Sources and build directories for each package.
- `build/tmp/work/blackparrot-poky-linux/linux-stable/5.15.24-r0/build/vmlinux` - Kernel ELF, helpful for debugging.
- `bp-yocto-layer/recipes-bsp/opensbi/opensbi_git.bb` - Build parameters for opensbi come from here, including PLATFORM_RISCV_ISA, PLATFORM_HART_COUNT.
- `bp-yocto-layer/recipes-kernel/linux/linux-stable_%.bbappend` - Manifest for kernel patches and configuration. Start here if you want to change kernel patches/config/device tree.
- `bp-yocto-layer/conf/machine/blackparrot.conf` - Selects kernel version, SBI platform, SBI device tree, and SBI payload.

## Workflow for Changing a Device Tree

### Setup: (you can skip this after the first time)

1. Clone Linux sources somewhere
2. Checkout v5.15
3. Apply patches from `bp-yocto-layer/recipes-kernel/linux/files/blackparrot/`

### Modify: 

4. Modify (or add new) device trees in `arch/riscv/boot/dts/blackparrot/`
5. Commit (or amend previous commit)
6. Use `git-format-patch v5.15` to create new patch files.
7. Copy them back into `bp-yocto-layer/recipes-kernel/linux/files/blackparrot/`
8. If you added a new patch file, you need to list it in `bp-yocto-layer/recipes-kernel/linux/linux-stable_%.bbappend`

### Rebuild:

Oneliner: `bitbake linux-stable && bitbake -c cleansstate opensbi && bitbake opensbi`.

9. Rebuild the kernel to compile the device trees with `bitbake linux-stable`. Bitbake will notice that you changed the sources (patches count as sources) and Do the Right Thing.
10. OpenSBI slurps the device trees out of the "deploy" directory in `build/tmp/deploy/`, and doesn't have a real dependency on them, so bitbake does not Do the Right Thing here and you need to rebuild it from scratch.
  10.a. `bitbake -c cleansstate opensbi` (not that this is clean-s-state, not clean-state).
  10.b. `bitbake opensbi`

#### The Fast Way:

```
$ dtc -I dts -O dtb -o ../yocto_repro/build/tmp/deploy/images/blackparrot/bp-1hart--5.15.24-r0-blackparrot-20220322003612.dtb arch/riscv/boot/dts/blackparrot/bp-1hart.dts
$ bitbake -c cleansstate opensbi && bitbake -c deploy opensbi
```

## Things that can be hard to figure out about Yocto/Poky/OE/BitBake/This entire arrangement:

- The `%` sign in a `.bbappend` filename acts as a wildcard so it will apply to any version.
- Even though the device trees are part of the kernel sources, they get slurped into OpenSBI and not the kernel. The yocto build process has a special procedure where it copies a device tree named by the `KERNEL_DEVICETREE` variable into the `deploy/images` directory, which OpenSBI finds through a combination of `RISCV_SBI_FDT` and some Python glue in `opensbi-payloads.inc`.
- OpenSBI includes the kernel and device tree because it's built in FW_PAYLOAD mode, but it doesn't have a dependency on the kernel. Stay mindful of this. If you change the kernel and need to force an OpenSBI rebuild, use `bitbake -c cleansstate opensbi`.
- If you need to increase the size of the mtd-ram rootfs, follow the above procedure to modify the device tree, then tweak the link script (`final_link.T`) accordinly.

## Troubleshooting

### `Resource temporarily unavailable`

This appears in the middle of a giant Python error. You probably forgot `ulimit -u 32768`.
