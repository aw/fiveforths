# FiveForths: Tutorials

[FiveForths](https://github.com/aw/fiveforths) is a tiny [Forth](https://www.forth.com/starting-forth/) written in hand-coded RISC-V assembly, initially designed to run on the 32-bit [Longan Nano](https://longan.sipeed.com/en/) (GD32VF103) microcontroller.

---

This document provides a quick guide to get started using _FiveForths_.

## Menu

1. [Requirements](#requirements)
2. [Wire the microcontroller](#wire-the-microcontroller)
3. [Get started](#get-started)
4. [Download it](#download-it)
5. [Build it](#build-it)
6. [Flash it](#flash-it)
7. [Use it](#use-it)

### Requirements

* Linux (tested on Debian bullseye) with _RISC-V_ cross-compilation binaries installed
* 32-bit GD32VF103 microcontroller
* USB cable for flashing firmware (using `dfu-util`), or Serial/USB UART (`PA9`, `PA10`) pins
* Serial/USB UART connected to JTAG (`PA13`, `PA14`, `PA15`, `PB3`) pins for debugging
* Manually built `openocd` and `gdb` installed in `/opt/riscv/` for debugging

### Wire the microcontroller

To wire the Serial/USB UART:

| Serial/USB pins | Microcontroller pins |
| :---- | :---- |
| RX | PA9 (T0) |
| TX | PA10 (R0) |
| 3.3V | 3V3 |
| GND | GND |

To wire the JTAG:

| Serial/USB JTAG pins | Microcontroller pins |
| :---- | :---- |
| RXD | JTDI |
| TXD | JTCK |
| RTS | JTDO |
| CTS | JTMS |
| 3.3V | 3V3 |
| GND | GND |

### Get started

It is possible to download a pre-built firmware binary, or build the firmware manually.

### Download it

Download one of the firmware binaries from the [releases page](https://github.com/aw/fiveforths/releases).

* [fiveforths-longan-nano-lite.bin](https://github.com/aw/fiveforths/releases/download/v0.3/fiveforths-longan-nano-lite.bin) (64K Flash, 20K RAM)
* [fiveforths-longan-nano.bin](https://github.com/aw/fiveforths/releases/download/v0.3/fiveforths-longan-nano.bin) (128K Flash, 32K RAM)

### Build it

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
/usr/bin/riscv64-unknown-elf-as -g -march=rv32imac -I src/boards/longan-nano-lite -I src/mcus/gd32vf103 -I src -o fiveforths.o fiveforths.s
/usr/bin/riscv64-unknown-elf-ld -m elf32lriscv -T src/boards/longan-nano-lite/linker.ld -o fiveforths.elf fiveforths.o
/usr/bin/riscv64-unknown-elf-objcopy -O binary fiveforths.elf fiveforths.bin
/usr/bin/riscv64-unknown-elf-objcopy -O ihex fiveforths.elf fiveforths.hex
/usr/bin/riscv64-unknown-elf-objdump -D -S fiveforths.elf > fiveforths.dump
```

Additional build options are explained in the [HOWTO](HOWTO.md) section.

The firmware file is called `fiveforths.bin` and is **nearly 2.5 KBytes** as of _release v0.3_ since _January 19, 2023_.

### Flash it

There are many ways to flash the firmware to the _Longan Nano_. There are a few good resources [here](https://github.com/riscv-rust/longan-nano/), [here](https://github.com/theandrew168/derzforth#program), [here](https://www.susa.net/wordpress/2019/10/longan-nano-gd32vf103/), [here](https://www.appelsiini.net/2020/programming-gd32v-longan-nano/), [here](https://sigmdel.ca/michel/ha/gd32v/longan_nano_01_en.html), and elsewhere. A reliable Serial/USB UART device is recommended, and flashing with the the python `stm32loader` tool is recommended, unless debugging with `GDB` then use `load` to flash the new firmware via the JTAG pins.

#### stm32loader

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

The device may be different from `/dev/ttyUSB0`.

It may be necessary to reset the device after flashing:

```
press RESET, release RESET
```

### Use it

Connect to the microcontroller over UART using a Serial/USB device and a terminal program.

#### pyserial

Install it with:

```
pip3 install pyserial
```

Connect with:

```
pyserial-miniterm --eol LF /dev/ttyUSB0 115200
```

---

Now that you've completed the tutorials, you're ready to read the other documents below:

* [EXPLAIN](EXPLAIN.md): learn the story behind _FiveForths_
* [HOWTO](HOWTO.md): build, usage, and code examples in Forth and RISC-V Assembly
* [REFERENCE](REFERENCE.md): learn the technical details, what's under the hood

# License

[MIT License](LICENSE)

FiveForths documentation and source code copyright © 2021~ [Alexander Williams](https://a1w.ca) and licensed under the permissive open source [MIT](https://opensource.org/licenses/MIT) license.
