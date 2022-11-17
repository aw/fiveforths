# November 17, 2022

## Deeper into the rabbit hole

I spent a day reading some old Forth books and comparing my implementation with how things were presented. In retrospect, my early decisions weren't as bad as I thought (except the 16-byte alignment). So I'll account for that in today's session.

### Log 3

I started by making a small adjustment to the `Makefile`.

```
-dump:
-               $(OBJDUMP) -D -S fiveforths.elf
+fiveforths.dump:
+               $(OBJDUMP) -D -S fiveforths.elf > fiveforths.dump
```

I noticed the old `make dump` was quite useful but too verbose, so instead I'm dumping it to a `fiveforths.dump` which can be inspected at my own pace. The output shows the memory locations of each function, constant, etc. In the previous log I talked a lot about _variables_ I defined, but those are actually hardcoded _constants_. I'll try to use the correct terminology moving forward.

#### Some Forth functions

Last year I made a [pull request to derzforth](https://github.com/theandrew168/derzforth/pull/10) to replace the hashing function with _djb2_hash_. That algorithm is quite small and efficient, so I thought I would use it in my _Forth_ implementation as well. It is used to uniquely identify (and find) a _Forth_ dictionary word. It's also used for user-defined words, but that can be quite slow: `O(N)`, so I'm considering perhaps also creating an index (see the reserved space for hash indexes in `fiveforths.s`) which would index them by their length, thus significantly reducing the lookup time - assuming a somewhat even distribution of words across the index. The index would be a simple hash table where the key would be length+name, and the value would be the _djb2_hash_ value. I haven't implemented it, but when I do i'll confirm if it's a viable and efficient approach.

Other than the hash function, I've also defined some functions (labels) for `_start`, `enter`, and `docol` which will be used later.

I'm still missing some functions to handle the terminal input buffer, which will be needed to transfer files between my PC and the microcontroller (via UART).

#### Some Forth words - the primitives

The aim is to write an extremely minimal _Forth_ in Assembly before incrementally adding features (new words) as needed. The basic set of primitives should be enough to bootstrap the system, where additional words can be defined in Forth.

Each word is defined using the `defcode` macro, and its hash was pre-computed using the _djb2_ hashing algorithm. Things prefixed with `# OK` comment above the code are confirmed working and tested. Everything else marked (`# FIXME`) has yet to be implemented.

It seems so far I'm only missing:

* `:`
* `;`
* `>in`
* `key`
* `emit`

#### Adjusting alignment

Macros are a real life saver. I modified the `PUSH`, `POP`, `PUSHRSP`, and `POPRSP` macros to align the pointer to 4 bytes (32-bits).

```
-    addi sp, sp, -16    # decrement DSP by 16 bytes (128-bit aligned)
+    addi sp, sp, -4     # decrement DSP by 4 bytes (32-bit aligned)
```

This should save some space on the stacks and allow for more data to be pushed. In this case I can probably decrease the stack sizes, since a 1KiB stack would leave space for 64 elements.. but with the new alignment we're at 256 stack elements.. which is probably way more than needed.. OK let's do that:

```
-.equ STACK_SIZE, 1024                   # 1 KiB
+.equ STACK_SIZE, 256                    # 256 Bytes
```

With this stack size we'll be able to push up to 64 elements per stack. I really hope to never reach that many, but if I do then it's a simple change anyways to increase the stack sizes.

#### Closing thoughts

There's clearly a lot left to do here (I know it's because I haven't really done anything yet). But so far I think I've been refamiliarized with the code. In the next session I'll jump to testing the code that's written so far, using a debugger and/or simulator. I'll also create a proper TODO list for the next steps so I can have a way to track my progress.
