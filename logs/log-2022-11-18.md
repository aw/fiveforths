# November 18, 2022

## Validating the implementation

I started this session by validating code that's been written and ensuring things are where they should be. I've also created an TODO list to [track my progress](https://github.com/aw/fiveforths/issues/1).

### Log 4

As mentioned previously, I defined some constants for the RAM size etc, but I'm not sure if they are actually placed at the correct location in memory. Let's have a look.

#### Constant locations

First I want to ensure the `__stacktop` address, i.e: the top of the stack, is correctly located at 0x20005000: `0x20000000 (start of RAM) + 0x5000 (size of RAM)` and placed into the `sp` (stack pointer / `x2`) register:

```
grep __stacktop fiveforths.dump 
    la sp, __stacktop
 800004c:	fb810113          	addi	sp,sp,-72 # 20005000 <__stacktop>
```

Perfect! Next, let's ensure our constants point to the correct location:

```
make readelf  | grep DSP_TOP
18: 20005000     0 NOTYPE  LOCAL  DEFAULT  ABS DSP_TOP
make readelf  | grep RSP_TOP
    19: 20004f00     0 NOTYPE  LOCAL  DEFAULT  ABS RSP_TOP
make readelf  | grep TIB
    20: 20004e00     0 NOTYPE  LOCAL  DEFAULT  ABS TIB_TOP
    21: 20004d00     0 NOTYPE  LOCAL  DEFAULT  ABS TIB
```

Great! The `DSP_TOP` should be at `0x20000000 (start of RAM) + 0x5000 (size of RAM) = 0x20005000`, the `RSP_TOP` should be at `0x20005000 - 0x100 (256 Bytes) = 0x20004F00`, and the `TIB_TOP` should be at `0x20004F00 - 0x100 (256 Bytes) = 0x20004E00`. Additionally, the lower address of `TIB` should be at `0x20004E00 - 0x100 (256 Bytes) = 0x20004D00`. So far so good, however..

#### Stack locations

I realized my stacks are placed at the wrong address, here's a look:

```
make readelf  | grep _stack
    22: 20000100     0 NOTYPE  LOCAL  DEFAULT    3 data_stack
    23: 20000200     0 NOTYPE  LOCAL  DEFAULT    3 return_stack
    24: 20000300     0 NOTYPE  LOCAL  DEFAULT    3 tib_stack
```

Oops! They are starting at the bottom of the stack and growing upwards, when in fact they should start at the top and grow downwards. Let's fix that:

```
-# reserve 3x 256 Bytes for stacks
-.bss
-.balign STACK_SIZE
-data_stack:
-    .space STACK_SIZE                   # reserve 256 Bytes for data stack
-return_stack:
-    .space STACK_SIZE                   # reserve 256 Bytes for return stack
-tib_stack:
-    .space STACK_SIZE                   # reserve 256 Bytes for terminal buffer
```

What? I realized that adding labels for these stacks and "reserving" zero-filled space in RAM was pointless. I also removed other reserved spaces for variables and indexes. The indexes will be added above the pad space, so let's define that:

```
-indexes:
-    .space (CELL * 64)                  # reserve 64 CELLS zero-filled
+.equ INDEXES, NOOP - (CELL * 64)        # 64 CELLS between NOOP and INDEXES
+.equ PAD, INDEXES - (CELL * 64)         # 64 CELLS between INDEXES and PAD
```

#### Additional changes

I made some other minor changes such as creating labels for the 'ok', '?', and 'redefined ok' strings, so we can easily jump to those when needed.

Since the _Longan Nano Lite_ has 64K FLASH and 20K RAM, and both are located in the same MCU chip, I think it makes more sense to keep the entire program and constants in FLASH, and only use the RAM for variables, stacks, and user-defined dictionary words. This is just my assumption the Forth can actually be executed from FLASH instead of RAM.

#### Closing thoughts

I've made some progress in improving the memory layout and size of the program, but there's still some work to do there. At least for now I can check off a few things from the TODO list. I planned on testing the current code this session but validating the memory locations/addresses was more work than expected, so I'll get to that next time before implementing the missing words.
