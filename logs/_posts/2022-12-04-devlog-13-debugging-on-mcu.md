# December 4, 2022

1. [Log 13](#log-13)
2. [Debugging on MCU](#debugging-on-mcu)
3. [Closing thoughts](#closing-thoughts)

## Log 13

In this session I'll focus on debugging directly on the MCU with `gdb` and `openocd`.

### Debugging on MCU

I started this session by wiring my [Longan Nano](https://longan.sipeed.com/en/) to my _FTDI FT232RL_ USB device. The device itself has all the pins broken out, which is very useful because it can now be used as a _JTAG_ debugger via [openocd](https://openocd.org)

Here's the pinout I used:

| FT232R / FT232RL pins | Longan Nano pins |
| ----: | :---- |
| RXD | JTDI |
| TXD | JTCK |
| RTS | JTDO |
| CTS | JTMS |
| 3.3V | 3.3V |
| GND | GND |

The best part of this approach, compared to the USB-C `dfu` upload, is it's not necessary to do the whole 2-finger 2-button "BOOT0/RESET" dance to upload a new firmware. You can upload a new firmware with just 1 command (`load` in gdb). And we get the added bonus that we can fully debug and inspect the MCU as it's running.

Next, you'll need to ensure you have [openocd installed](https://github.com/riscv-mcu/riscv-openocd) (compiled from scratch to support the `GD32VF103` MCU), and run it using the two scripts included in this repository:

```
/path/to/openocd -f ft232r.cfg -f openocd.cfg
```

The output should look similar to this:

```
Open On-Chip Debugger 0.11.0+dev-01861-g6edf98db7-dirty (2021-10-27-18:59)
Licensed under GNU GPL v2
For bug reports, read
	http://openocd.org/doc/doxygen/bugs.html
Info : only one transport option; autoselect 'jtag'
adapter speed: 1000 kHz

Info : clock speed 1000 kHz
Info : JTAG tap: riscv.cpu tap/device found: 0x1000563d (mfg: 0x31e (Andes Technology Corporation), part: 0x0005, ver: 0x1)
Warn : JTAG tap: riscv.cpu       UNEXPECTED: 0x1000563d (mfg: 0x31e (Andes Technology Corporation), part: 0x0005, ver: 0x1)
Error: JTAG tap: riscv.cpu  expected 1 of 1: 0x1e200a6d (mfg: 0x536 (Nuclei System Technology Co Ltd), part: 0xe200, ver: 0x1)
Info : JTAG tap: auto0.tap tap/device found: 0x790007a3 (mfg: 0x3d1 (GigaDevice Semiconductor (Beijing) Inc), part: 0x9000, ver: 0x7)
Error: Trying to use configured scan chain anyway...
Warn : AUTO auto0.tap - use "jtag newtap auto0 tap -irlen 5 -expected-id 0x790007a3"
Warn : Bypassing JTAG setup events due to errors
Info : datacount=4 progbufsize=2
Info : Examined RISC-V core; found 1 harts
Info :  hart 0: XLEN=32, misa=0x40901105
Info : starting gdb server for riscv.cpu on 3333
Info : Listening on port 3333 for gdb connections
Info : Listening on port 6666 for tcl connections
Info : Listening on port 4444 for telnet connections
```

I also wanted to setup a `debug.gdb` file which contains commands to run whenever I want to enter a debug session:

```
target extended-remote :3333

# print demangled symbols
set print asm-demangle on

set confirm off

# set backtrace limit to not have infinite backtrace loops
set backtrace limit 32

monitor reset halt
load
break _start
break _continue
```

It can be used like this:

```
/path/to/riscv64-unknown-elf-gdb -command=debug.gdb fiveforths.elf
```

This will connect to the `openocd` session, reset the MCU, upload the latest firmware file (`fiveforths.elf`), and set two breakpoints.

From there you can continue to run, inspect registers, or single-step through the program:

```
(gdb) c
Continuing.

Breakpoint 1, _start () at fiveforths.s:149
149	    la sp, __stacktop   # initialize DSP register

(gdb) info registers
ra             0x80002f0	0x80002f0 <body_COLON+36>
sp             0x20005000	0x20005000
</snip>

(gdb) si
0x08000048 in _start () at fiveforths.s:149
149	    la sp, __stacktop   # initialize DSP register
```

### Closing thoughts

That's all for this session. I kept it short because I just wanted to validate and ensure this thing actually runs on the Longan Nano (it does). In the next session I'll jump straight to the I/O functions and interpreter.
