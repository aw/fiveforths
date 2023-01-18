# FiveForths: Reference

[FiveForths](https://github.com/aw/fiveforths) is a tiny [Forth](https://www.forth.com/starting-forth/) written in hand-coded RISC-V assembly, initially designed to run on the 32-bit [Longan Nano](https://longan.sipeed.com/en/) (GD32VF103) microcontroller.

---

This document provides technical details about what's under the hood of _FiveForths_.

## Menu

1. [FiveForths specification](#fiveforths-specification)
2. [Primitives list](#primitives-list)
3. [Registers list](#registers-list)
4. [Source files list](#source-files-list)
5. [Memory map](#memory-map)
6. [Word header](#word-header)
7. [Hash format](#hash-format)
8. [Other Forths](#other-forths)

### FiveForths specification

Below is a list of specifications for _FiveForths_, most can be changed in the source files:

* Support for 32-bit `GD32VF103` microcontrollers on the _Longan Nano_ board
* CPU configured to run at `8 MHz`
* UART configured for `115,200` baud rate, `8N1`
* Data Stack (DSP) size: `256 Bytes`
* Return Stack (RSP) size: `256 Bytes`
* Terminal Input Buffer (TIB) size: `256 Bytes`
* Pad Buffer (PAD) size: `256 Bytes`
* Threading mode: `Indirect Threaded Code` (ITC)
* Word header size: `12 Bytes` (3 CELLs)
* Word name storage: `32-bit hash` (djb2)
* Return character newline: `\n`
* Maximum word length: `32 characters`
* Stack effects comments support `( x -- x )`: **yes**
* Backslash comments support `\ comment`: **yes**
* Multiline code definitions support: **no**
* OK message: `"   ok\n"`
* ERROR message: `"  ?\n"`

### Primitives list

Below is the list of _Forth_ primitives, there are currently **19 primitives**:

| Word | Stack Effects | Description |
| :---- | :---- | :---- |
| |
| `reboot` | ( -- ) | Reboot the entire system and initialize memory |
| `@` | ( addr -- x ) | Fetch memory at addr |
| `!` | ( x addr -- ) | Store x at addr |
| `sp@` | ( -- addr ) | Get current data stack pointer |
| `rp@` | ( -- addr ) | Get current return stack pointer |
| `0=` | ( x -- f ) | -1 if top of stack is 0, 0 otherwise |
| `+` | ( x1 x2 -- n ) | Add the two values at the top of the stack |
| `nand` | ( x1 x2 -- n ) | Bitwise NAND the two values at the top of the stack |
| `lit` | ( -- n ) | Get the next word from IP and push it to the stack, increment IP |
| `exit` | ( r:addr -- ) | Resume execution at address at the top of the return stack |
| |
| `key` | ( -- x ) | Read 8-bit character from uart input |
| `emit` | ( x -- ) | Write 8-bit character to uart output |
| |
| `tib` | ( -- addr ) | Store `TIB` variable value in top of data stack
| `state` | ( -- addr ) | Store `STATE` variable value in top of data stack
| `>in` | ( -- addr ) | Store `TOIN` variable value in top of data stack
| `here` | ( -- addr ) | Store `HERE` variable value in top of data stack
| `latest` | ( -- addr ) | Store `LATEST` variable value in top of data stack
| |
| `:` | ( -- ) | Start the definition of a new word |
| `;` | ( -- ) | End the definition of a new word |

### Registers list

The following _Forth_ registers are assigned to _RISC-V_ registers below. The source files also use additional registers such as temporaries (`t0` to `t6`).

| Forth name | RISC-V name | Description |
| :----: | :----: | :---- |
| DSP | sp | data stack pointer |
| W | a0 | working register |
| X | a1 | working register |
| Y | a2 | working register |
| Z | a3 | working register |
| FP | s0 | frame pointer (unused for now) |
| IP | s1 | instruction pointer |
| RSP | s2 | return stack pointer |

### Source files list

The firmware binary is built using `GNU as`, so all source files have the lowercase `.s` extension.

| Filename | Description |
| :---- | :---- |
| [fiveforths.s](fiveforths.s) | Loads the actual source files from `src/` |
| **`src/`** |
| [01-variables-constants.s](src/01-variables-constants.s) | Some constants which are stored in Flash memory, but which may point to memory addresses to be used as variables |
| [02-macros.s](src/02-macros.s) | Macros to avoid repeating code throughout the source files |
| [03-interrupts.s](src/03-interrupts.s) | The interrupt initialization and handling routines |
| [04-io-helpers.s](src/04-io-helpers.s) | Helpers to send and receive characters over the UART |
| [05-internal-functions.s](src/05-internal-functions.s) | Functions called by the interpreter such as hashing and lookup functions |
| [06-initialization.s](src/06-initialization.s) | Initialization routines when the board is booted or reset |
| [07-error-handling.s](src/07-error-handling.s) | Error handling routines and messages to be printed |
| [08-forth-primitives.s](src/08-forth-primitives.s) | The Forth primitive words |
| [09-interpreter.s](src/09-interpreter.s) | The interpreter functions to process UART characters, execute and compile words |
| **`src/boards/<board>/`** |
| [boards.s](src/boards/longan-nano-lite/boards.s) | Variables and constant specific to the `<board>` |
| [linker.ld](src/boards/longan-nano-lite/linker.ld) | Linker script specific to the `<board>` |
| **`src/mcus/<mcu>/`** |
| [mcu.s](src/mcus/gd32vf103/mcu.s) | Variables and constant specific to the `<mcu>` |

### Memory map

The stack size is defined in `mcu.s` and defaults to 256 bytes for the `Data, Return, Terminal` stacks. The `Data` and `Return` stacks grow _downward_ from the top of the memory. The `Terminal` buffer grows _upward_ from the start of the `Variables` area. The `User Dictionary` grows _upward_ from the bottom of the memory. Currently `5` Cells are used to store variables. There is also an additional `64` Cells reserved for the `Pad` area, which can grow _upward or downward_. The `Pad` area is not exposed in _Forth_ and should be used exclusively by internal code or new Assembly primitives - as an in-memory scratchpad without affecting the other stacks or user dictionary.

```
Top
+-----------------+-------------------------+
| Memory Map      | Size (1 Cell = 4 Bytes) |
+-------------------------------------------+
|                 |                         |  |
| Data Stack      | 64 Cells (256 Bytes)    |  |
|                 |                         |  v
+-------------------------------------------+
|                 |                         |  |
| Return Stack    | 64 Cells (256 Bytes)    |  |
|                 |                         |  v
+-------------------------------------------+
|                 |                         |  ^
| Terminal Buffer | 64 Cells (256 Bytes)    |  |
|                 |                         |  |
+-------------------------------------------+
|                 |                         |
| Variables       |  5 Cells (20 Bytes)     |
|                 |                         |
+-------------------------------------------+
|                 |                         |  ^
| Pad Area        | 64 Cells (256 Bytes)    |  |
|                 |                         |  v
+-------------------------------------------+
|                 |                         |  ^
|                 |                         |  |
|                 |                         |  |
| User Dictionary | Variable size           |  |
|                 |                         |  |
|                 |                         |  |
|                 |                         |  |
+-----------------+-------------------------+
```

### Word header

A dictionary word header contains 3 Cells (3 x 32 bits = 12 bytes). The `Link` is the value of the last defined word, which is stored in the variable `LATEST`. The `Hash` is generated by the `djb2_hash` function. And the `Codeword` is the address of the `.addr` label which jumps to the `docol` function.

```
+----------+----------+-------------+
|   Link   |   Hash   |  Codeword   |
+----------+----------+-------------+
 32-bits    32-bits    32-bits
```

### Hash format

The hash is a 32-bit hash with the last 8 bits (from the LSB) used for the Flags (3 bits) and Length (5 bits) of the word.

```
             32-bit hash
+-------+--------+------------------+
| FLAGS | LENGTH |      HASH        |
+-------+--------+------------------+
 3-bits  5-bits   24-bits
```

### Other Forths

This document would be incomplete without listing other Forths which inspired me and are worth checking out:

* [colorForth, by Chuck Moore (inventor)](https://colorforth.github.io/cf.htm)
* [Mecrisp, batteries-included with FPGA support](https://mecrisp.sourceforge.net/)
* [sectorforth, super tiny 16-bit implementation](https://github.com/cesarblum/sectorforth)
* [jonesforth, 32-bit heavily documented](https://rwmj.wordpress.com/2010/08/07/jonesforth-git-repository/)
* [derzforth, 32-bit risc-v inspiration](https://github.com/theandrew168/derzforth)
* [nasmjf, the devlog idea and well documented](http://ratfactor.com/nasmjf/)
* [CamelForth, by Brad Rodriguez (Moving Forth)](http://www.camelforth.com)
* [muforth, the sum of all Forth knowledge](https://muforth.nimblemachines.com/)

Additional information can be found in the [devlogs](https://aw.github.io/fiveforths).

---

Now that you've grokked the reference, you're ready to read the other documents below:

* [TUTORIALS](TUTORIALS.md): a quick guide to **get started**
* [EXPLAIN](EXPLAIN.md): learn the story behind _FiveForths_
* [HOWTO](HOWTO.md): build, usage, and code examples in Forth and RISC-V Assembly

# License

[MIT License](LICENSE)

FiveForths documentation and source code copyright © 2021~ [Alexander Williams](https://a1w.ca) and licensed under the permissive open source [MIT](https://opensource.org/licenses/MIT) license.
