# 32-bit RISC-V Forth for microcontrollers

[![GitHub release](https://img.shields.io/github/release/aw/fiveforths.svg)](https://github.com/aw/fiveforths)

[FiveForths](https://github.com/aw/fiveforths) is a tiny [Forth](https://www.forth.com/starting-forth/) written in hand-coded RISC-V assembly, initially designed to run on the 32-bit [Longan Nano](https://longan.sipeed.com/en/) (GD32VF103) microcontroller.

_FiveForths_ currently uses the _indirect threading_ model and only has 19 built-in primitive words. It is 100% fully functional and can be extended by adding new primitives (in Assembly) or by defining new words (in Forth). This implementation is loosely inspired by [sectorforth](https://github.com/cesarblum/sectorforth), [jonesforth](https://github.com/nornagon/jonesforth), and [derzforth](https://github.com/theandrew168/derzforth).

Development progress has been logged regularly in the [devlogs](https://aw.github.io/fiveforths/).

---

1. [Requirements](#requirements)
2. [Getting started](#getting-started)
3. [Flashing the firmware](#flashing-the-firmware)
4. [About FiveForths](#about-fiveforths)
5. [Todo](#todo)
8. [Contributing](#contributing)
9. [Changelog](#changelog)
10. [Other Forths](#other-forths)
11. [License](#license)

# Requirements

* Linux (tested on Debian bullseye) with _RISC-V_ cross-compilation binaries installed
* 32-bit GD32VF103 microcontroller
* USB cable for flashing firmware (using `dfu-util`), or Serial/USB UART (`PA9`, `PA10`) pins
* Serial/USB UART connected to JTAG (`PA13`, `PA14`, `PA15`, `PB3`) pins for debugging
* Manually built `openocd` and `gdb` installed in `/opt/riscv/` for debugging only

# Getting started

It is possible to download a firmware binary or build the firmware manually.

## Download it

Download one of the firmware binaries from the [releases page](https://github.com/aw/fiveforths/releases).

* [fiveforths-longan-nano-lite.bin](https://github.com/aw/fiveforths/releases/download/v0.2/fiveforths-longan-nano-lite.bin) (64K Flash, 20K RAM)
* [fiveforths-longan-nano.bin](https://github.com/aw/fiveforths/releases/download/v0.2/fiveforths-longan-nano.bin) (128K Flash, 32K RAM)

## Build it

The first step is to prepare the environment for building the firmware:

```
sudo apt-get install build-essential binutils-riscv64-unknown-elf gcc-riscv64-unknown-elf
```

This should install the _RISC-V_ binaries in `/usr/bin/` prefixed with: `riscv64-unknown-elf-`

Next, clone this repository:

```
git clone https://github.com/aw/fiveforths.git
cd fiveforths
```

Finally, build the firmware and debug files with `make`. The output should look like this:

```
$ make
/usr/bin/riscv64-unknown-elf-as -g -march=rv32imac  -I src -o fiveforths.o fiveforths.s
/usr/bin/riscv64-unknown-elf-ld -m elf32lriscv -T fiveforths.ld -o fiveforths.elf fiveforths.o
/usr/bin/riscv64-unknown-elf-objcopy -O binary fiveforths.elf fiveforths.bin
/usr/bin/riscv64-unknown-elf-objcopy -O ihex fiveforths.elf fiveforths.hex
/usr/bin/riscv64-unknown-elf-objdump -D -S fiveforths.elf > fiveforths.dump
```

The firmware file is called `fiveforths.bin` and is **under 2 KBytes** as of _release v0.1_ since _January 08, 2023_.

# Flashing the firmware

There are many ways to flash the firmware to the _Longan Nano_. There are a few good resources [here](https://github.com/riscv-rust/longan-nano/), [here](https://github.com/theandrew168/derzforth#program), [here](https://www.susa.net/wordpress/2019/10/longan-nano-gd32vf103/), [here](https://www.appelsiini.net/2020/programming-gd32v-longan-nano/), [here](https://sigmdel.ca/michel/ha/gd32v/longan_nano_01_en.html), and elsewhere. I personally use a Serial/USB UART and flash it using the python `stm32loader` tool, unless I'm debugging with `GDB` then I'll use `load` to flash the new firmware via the JTAG pins.

## stm32loader

Install it with:

```
pip3 install stm32loader
```

Set the _Longan Nano_ into `boot mode`:

```
press BOOT, press RESET, release RESET, release BOOT
```

Flash the firmware with:

```
stm32loader -p /dev/ttyUSB0 -ewv fiveforths.bin
```

The output should look like this:

```
Activating bootloader (select UART)
Bootloader version: 0x30
Chip id: 0x410 (STM32F10x Medium-density)
Supply -f [family] to see flash size and device UID, e.g: -f F1
Extended erase (0x44), this can take ten seconds or more
Write 8 chunks at address 0x8000000...
Writing ████████████████████████████████ 8/8
Read 8 chunks at address 0x8000000...
Reading ████████████████████████████████ 8/8
Verification OK
```

The device may be different from `/dev/ttyUSB0`, but I'm sure you can figure it out.

# About FiveForths

The source files are:

* [fiveforths.s](fiveforths.s): lists the register assignment and loads the actual source files from `src/`.
* [src/01-variables-constants.s](src/01-variables-constants.s): defines some constants which are stored in Flash memory, but which may point to memory addresses to be used as variables.
* [src/02-macros.s](src/02-macros.s): defines macros to avoid repeating code throughout the source files.

**WIP**

# TODO

- [ ] Finish writing this README
- [x] Fix remaining bugs (carriage return issue)
- [ ] Implement bounds checks for stacks and dictionary
- [ ] Code cleanup and optimizations
- [ ] Add example Forth code to turn it into a "real" Forth (ex: `[`, `]`, `branch`, etc)

# Contributing

Please create a pull-request or [open an issue](https://github.com/aw/picolisp-kv/issues/new) on GitHub.

# Changelog

## 0.2 (2023-01-10)

  * Fix issue #9 - Handling of carriage return
  * Fix issue #11 - Ignore non-printable characters
  * Re-organize code to support different boards and MCUs
  * Add GitHub action to automatically build and publish the firmware binaries

## 0.1 2023-01-09 - First release

# Other Forths

This document would be incomplete without listing other Forths which inspired me and are worth checking out:

* [colorForth, by Chuck Moore (inventor)](https://colorforth.github.io/cf.htm)
* [Mecrisp, batteries-included with FPGA support](https://mecrisp.sourceforge.net/)
* [sectorforth, super tiny 16-bit implementation](https://github.com/cesarblum/sectorforth)
* [jonesforth, 32-bit heavily documented](https://rwmj.wordpress.com/2010/08/07/jonesforth-git-repository/)
* [derzforth, 32-bit risc-v inspiration](https://github.com/theandrew168/derzforth)
* [nasmjf, the devlog idea and well documented](http://ratfactor.com/nasmjf/)
* [CamelForth, by Brad Rodriguez (Moving Forth)](http://www.camelforth.com)
* [muforth, the sum of all Forth knowledge](https://muforth.nimblemachines.com/)

# License

[MIT License](LICENSE)

Copyright (c) 2021~ Alexander Williams, On-Prem <license@on-premises.com>
