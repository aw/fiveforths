# FiveForths: Howto

[FiveForths](https://github.com/aw/fiveforths) is a tiny [Forth](https://www.forth.com/starting-forth/) written in hand-coded RISC-V assembly, initially designed to run on the 32-bit [Longan Nano](https://longan.sipeed.com/en/) (GD32VF103) microcontroller.

---

This document provides more detailed information on build, use, and write code for this microcontroller.

## Menu

1. [Building for other boards](#building-for-other-boards)
2. [Rebuilding the firmware](#rebuilding-the-firmware)
3. [Debug with JTAG](#debug-with-jtag)
4. [Defining words (Forth)](#defining-words)
5. [Turning on an LED](#turning-on-an-led)
6. [Adding primitives (Assembly)](#adding-primitives)

### Building for other boards

There are currently 2 support boards:

* [longan-nano-lite (default)](#build-longan-nano-lite)
* [longan-nano](#build-longan-nano)

#### Build longan nano lite

To build the lite version of _Longan Nano_, which is limited to 64K Flash, 20K RAM, type the following:

```
make build BOARD=longan-nano-lite
```

#### Building longan nano

To build the regular _Longan Nano_, which has 128K Flash, 32K RAM, type the following:

```
make build BOARD=longan-nano
```

### Rebuilding the firmware

To rebuild the firmware:

```
make build -B
```

Or first clean, then build:

```
make clean
make build
```

### Debug with JTAG

JTAG debugging is necessary when modifying the firmware and to inspect memory and registers while the CPU is halted.

#### Load openocd

```
make openocd &
```

If [openocd](https://openocd.org/pages/getting-openocd.html) doesn't work, it is necessary to install it to `/opt/riscv/` and it may be necessary to modify the adapter config in `ft232r.cfg` to match your adapter.

#### Load GDB

```
make debug
```

Once `GDB` is loaded, the firmware can be uploaded quickly with:

```
load
```

Registers can be inspected with (for example):

```
info registers a0 a1 t0 t1 sp pc
```

or:

```
info all-registers
```

### Defining words

Accessing _FiveForths_ through the terminal should look similar to this:

```
--- Miniterm on /dev/ttyUSB0  115200,8,N,1 ---
--- Quit: Ctrl+] | Menu: Ctrl+T | Help: Ctrl+T followed by Ctrl+H ---
FiveForths v0.3, Copyright (c) 2021~ Alexander Williams, https://a1w.ca

```

Some basic words can then be defined (borrowed from [sectorforth hello-world](https://github.com/cesarblum/sectorforth/blob/master/examples/01-helloworld.f) and [planckforth bootstrap](https://github.com/nineties/planckforth/blob/main/bootstrap.fs)):

```
: dup sp@ @ ;
: invert -1 nand ;
: negate invert 1 + ;
: - negate + ;
: drop dup - + ;
: over sp@ 4 + @ ;
: swap over over sp@ 12 + ! sp@ 4 + ! ;
: nip swap drop ;
: 2dup over over ;
: 2drop drop drop ;
: and nand invert ;
: or invert swap invert nand ;
: = - 0= ;
: <> = invert ;
: , here @ ! here @ 4 + here ! ;
: immediate latest @ 4 + dup @ 2147483648 or swap ! ;
: [ 0 state ! ; immediate
: ] 1 state ! ;
: branch rp@ @ dup @ + rp@ ! ;
```

Of course, it is possible to define many other words to suit your needs.

### Turning on an LED

The following code can be used to turn on the blue LED on GPIOA pin 2:

```
: blue_led 0x40010800 @ 0xFFFFF0FF and 0x00000300 or 0x40010800 ! ;
blue_led
```

This requires the above defined words: `or, invert, swap, over, and`.

To explain the values:

* `0x40010800`: GPIOA base address with offset `0x00` for `CTL0` pins 0-7 (would be `CTL1` with offset `0x04` for pins 8-15).
* `0xFFFFF0FF`: mask to clear GPIO pin 2 (would be the same for GPIO pin 10, while GPIO pin 5 would be `0xFF0FFFFF` and GPIO pin 8 would be `0xFFFFFFF0`).
* `0x00000300`: GPIO pin 2 setting `0b0011` which is `push-pull output, max speed 50MHz`.

The code above uses those pre-calculated values to read the existing GPIOA config from a memory address (with `@`), apply a mask (with `and`), apply the new config (with `or`), then store it back to the memory address (with `!`), thus writing the new GPIOA which sets pin 2 low (active-low, therefore it turns on the blue LED).

### Adding primitives

New primitives can be written in RISC-V Assembly. It is recommended to add them to a **new file** and then include the file at _the end_ of `fiveforths.s`:

```
# fiveforths.s

.include "my-primitives.s"
```

In `my-primitives.s`, each new primitive should start with a call to the `defcode` macro, and they should end with the `NEXT` macro. For example:

```
# exit ( r:addr -- )    Resume execution at address at the top of the return stack
defcode "exit", 0x04967e3f, EXIT, LIT
    POPRSP s1           # pop RSP into IP
    NEXT
```

The macro arguments are:

* primitive: used in the interactive **Forth** terminal. (ex: `exit`)
* djb2_hash: the hash of the primitive with the first 3 bits (from the MSB) reserved for the flags (immediate, hidden, user), the next 5 bits reserved for the size (1-32). (ex: `0x04967e3f`) 
* name of the primitive: uppercase name used by the interpreter to find the label of the word. (ex: `EXIT`)
* name of the previous primitive: uppercase name of the previous primitive this one _links_ to, used for dictionary lookups (linked list). (ex: `LIT`)

Existing primitives can be used for inspiration, they are located in `src/08-forth-primitives.s`.

#### Generating a djb2 hash

First, compile the `djb2` hash program:

```
make djb2
```

Then run the binary with the name of the primitive, example:

```
./djb2 exit
djb2_hash: 0x04967e3f
```

The hash `0x04967e3f` will be printed, which can be used in the `defcode` declaration.

---

Now that you've completed the howto, you're ready to read the other documents below:

* [TUTORIALS](TUTORIALS.md): a quick guide to **get started**
* [EXPLAIN](EXPLAIN.md): learn the story behind _FiveForths_
* [REFERENCE](REFERENCE.md): learn the technical details, what's under the hood

# License

[MIT License](LICENSE)

FiveForths documentation and source code copyright © 2021~ [Alexander Williams](https://a1w.ca) and licensed under the permissive open source [MIT](https://opensource.org/licenses/MIT) license.
