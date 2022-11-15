# November 14, 2022

## Hello World

This log serves as a memory dump for my thought process while working on my custom 32-bit RISC-V Forth implementation. The idea is borrowed from [Dave's NASM Forth](https://ratfactor.com/assembly-nights) where he meticulously logged his "dev nights" while working on his port of Jonesforth.

### How to follow along

Just read it chronologically. I've opted to write in Markdown to make it easy to differentiate my thoughts VS my code/commands typed in the terminal.

### Log 1

I began working on my Forth one year ago, in November 2021. Progress ended one month later because _life_ focused my priorities on other things. The terminal is now reopened, but I need to refresh myself with the codebase haha.

#### Getting started, again

To start, on Debian 11 it's possible to install the `risc-v` cross-compiler tools for `rv32imac`, the target architecture of my `longan nano` 32-bit RISC-V hardware microcontroller.

```
apt-get install binutils-riscv64-unknown-elf gcc-riscv64-unknown-elf
```

Compile everything using `make`.

It generates a series of files for debugging locally:

* `fiveforths.s`: the actual source code for this Forth implementation.
* `fiveforths.o`: the compiled source code (using GNU AS) with all the object data, used to generate the ELF file.
* `fiveforths.elf`: a nice verbose dump of the ELF data which can be read with `make readelf`, and is used to generate the `.bin` and `.hex` files.
* `fiveforths.bin`: the binary file which gets flashed to the MCU (don't flash it, it doesn't work).
* `fiveforths.hex`: a hex file which can be uploaded to a web-based RISC-V simulator (ex: [emulsiV](https://riscuinho.github.io/emulsiV/)).

I was using GDB to test and debug the code locally, without flashing the MCU, but we'll get to that later.

#### My Forth implementation

This implementation is also somewhat inspired by [sectorforth](https://github.com/cesarblum/sectorforth), [jonesforth](https://github.com/nornagon/jonesforth), and [derzforth](https://github.com/theandrew168/derzforth). I made some changes to their implementations which are not set in stone, simply because I thought they would be cool and useful, but maybe they're not... they'll be explained in future logs.

**Memory Map**

```
+-----------------+-------------------------+
|                 |                         |
| Memory Map      | Size (1 Cell = 32 bits) |
|                 |                         |
+-------------------------------------------+
|                 |                         |
| Data Stack      | 8192 Cells (1KiB)       |
|                 |                         |
+-------------------------------------------+
|                 |                         |
| Return Stack    | 8192 Cells (1KiB)       |
|                 |                         |
+-------------------------------------------+
|                 |                         |
| Terminal Buffer | 8192 Cells (1 KiB)      |
|                 |                         |
+-------------------------------------------+
|                 |                         |
| Pad Area        | 64 Cells (256 Bytes)    |
|                 |                         |
+-------------------------------------------+
|                 |                         |
|                 |                         |
|                 |                         |
| Dictionary      | Variable size           |
|                 |                         |
|                 |                         |
|                 |                         |
+-----------------+-------------------------+
```

* `Data stack`: 1KiB, starts at the highest address `0x20000000` + the size of the RAM (20KiB for longan nano lite), and grows down towards the _Return stack_.
* `Return stack`: 1KiB, starts right below the bottom of the _Data stack_, and grows down towards the _Terminal buffer_.
* `Terminal buffer`: 1KiB, starts right below the bottom of the _Return stack_, and grows down towards the _Pad area_.
* `Pad area`: 64 cells (32 bits * 64), starts right below the bottom of the _Terminal buffer_, and grows down towards the _Dictionary_ for Forth words etc.
* `Dictionary`: Variable sized, starts right at the start of the RAM memory, and grows up towards the bottom of the _Pad area_.

Now here's the funny thing, I don't even know if the way I defined the memory map using `.equ` and `.balign` is correct. I think I'm missing a _layout_ file to tell GNU AS how/where to place things.. I'll focus on that later.

#### Closing thoughts

In the next log I'll discuss the register variables, macros, and functions which I've implemented and confirmed work (the ones with an `# OK` comment right above).
