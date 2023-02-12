# January 10

1. [Log 37](#log-37)
2. [A release or two](#a-release-or-two)
3. [Why so much work](#why-so-much-work)
4. [Closing thoughts](#closing-thoughts)

### Log 37

In this session I'll discuss the latest changes I've made to the source code, and provide information on the releases.

### A release or two

In the last day I've published [2 releases](https://github.com/aw/fiveforths/releases) to GitHub. The first, `v0.1` was a partial failure because I didn't realize the `firmware.bin` did not automatically jump to the `_start` label. I fixed this by moving it to the `src/03-interrupts.s` source file:

```
# Ensure the _start entry label is defined first
.text
.global _start
_start:
    j boot
```

The _backspace_ issue where typing it would completely mess up the `TIB` is now fixed. Well it turns out there was a line of code which shouldn't have been there (so I removed it):

```
-    sw a1, 0(t3)            # store new TOIN value in memory
```

This code was storing the updated `TOIN` address back to memory, before we even started processing the token. Oops!

Another change was to add the `lit` primitive, which makes it possible to add numbers to a colon definition. For example, this works:

```
: add5 5 + ;
10 add5
```

The stack pointer would then have the decimal value `15`. Here's the code for `LIT`, it's inserted right after `NAND` and `EXIT`:

```
# lit ( -- n )          Get the next word from IP and push it to the stack, increment IP
defcode "lit", 0x03888c4e, LIT, NAND
    lw t0, 0(s1)        # load the memory address from IP into temporary
    PUSH t0             # push the literal to the top of the stack
    addi s1, s1, CELL   # increment IP by 1 CELL
    NEXT
```

There's some other code added to the `push_number` routine which handles inserting the `LIT` codeword address to a colon definition (in memory), followed by the actual number, if the `STATE` of the interpreter was set to `1` (_compile mode_).

Finally, that release saw the initial introduction of some actual _documentation_ in the form of a `README`. It's not complete and not final, as I plan to introduce proper documentation in the near future.

The second release, `v0.2` is a bit more polished and has a few improvements.

The _carriage return_ and _zero_ control characters are now completely ignored in the `interpreter` function:

```
# ignore specific characters
mv t4, zero                                 # load 0x00 zero into temporary
beq a0, t4, interpreter                     # ignore the character if it matches
li t4, CHAR_CARRIAGE                        # load 0x0D carriage return into temporary
beq a0, t4, interpreter                     # ignore the character if it matches
```

We're ignoring only those ones and not the entire set of _non-printable_ characters because the others aren't really problematic, but I may be wrong. It's not a big deal either way, and can easily be changed if needed.

The location of the `_start` entry symbol was revised and moved to the top of the `fiveforths.s` source file. This guarantees it'll be located at the start of Flash (`0x08000000`).

There's now a boot message when you first boot/reset the microcontroller, the terminal will display this uneventful greeting:

```
FiveForths v0.2, Copyright (c) 2021~ Alexander Williams, https://a1w.ca

```

We now have a visual indicator that the _Forth_ is booted and ready to accept commands. Yay!

The last three changes are mostly cosmetic but equally important:

First, I moved all these devlog _posts_ and their related assets, html pages, build files, etc to the `gh-pages` git branch. The goal was to cleanup and reorganize the repository so the code remains in the `master` branch, separate from the [devlogs](https://fiveforths.a1w.ca) website.

Next, the `Makefile` was heavily modified to support building different types of boards with different types of microcontrollers. Some code was split out from the `src/` source files and moved into `src/mcus/gd32vf103/mcu.s`, and other code was moved to `src/boards/longan-nano-lite/board.s`. I also added a simplified linker script for each board (ex: the `longan-nano` has slightly more RAM and double the FLASH of the `longan-nano-lite`).

Now it's possible to specify command-line variables for `make` to create various firmware binaries. Here are a few examples:

```
make build BOARD=longan-nano
make build BOARD=longan-nano-lite
```

There's a few other options but they'll be described in the upcoming documentation.

Finally, I added a [GitHub Action](https://docs.github.com/en/actions) to automate the firmware builds from this repository. At the moment it builds `longan-nano` and `longan-nano-lite` firmware, generates the sha256 hash, and uploads them as an artifact of the build process. I then use those exact files in [the release](https://github.com/aw/fiveforths/releases/tag/v0.2). This means you don't even need the whole RISC-V setup to try _FiveForths_, just grab a binary, flash it, and get to work.

### Why so much work

Why put so much effort into a _[just for fun](https://justforfunnoreally.dev/)_ open source project?

Well this project was [discovered by Hackaday.io](https://hackaday.com/2023/01/08/forth-cracks-risc-v) and [written about on Hackster.io](https://www.hackster.io/news/alexander-williams-fiveforths-is-a-hand-written-risc-v-assembly-forth-for-microcontrollers-573b5f0ed9f8), so I suddenly found myself with a pressing need to take this a bit more seriously. I want to make it easier for people to try it, learn more about it, and possibly even provide contributions. Did I mention it's fun?

### Closing thoughts

I want to make a random shoutout to [Daniel Mangum](https://github.com/hasheddan) who did a fantastic job of [documenting some RISC-V](https://danielmangum.com/categories/risc-v-bytes/) things.

The next release will include the updated documentation which I believe will be very helpful for people who want a better idea about _FiveForths_ without browsing through the source code. It will also contain some **Forth** code examples and other useful information.

In the next coding session, I'll likely focus on the remaining open [GitHub issues](https://github.com/aw/fiveforths/issues), which I labeled as "enhancements" because they aren't critical to the functioning of _FiveForths_.
