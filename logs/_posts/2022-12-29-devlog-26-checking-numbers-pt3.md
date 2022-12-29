# December 29, 2022

1. [Log 26](#log-26)
2. [Checking numbers pt3](#checking-numbers-pt3)
3. [Interpreter pt4](#interpreter-pt4)
4. [Closing thoughts](#closing-thoughts)

### Log 26

Never 2 without 3? Well in this case I just found a small bug, fixed it, and i'm back to the interpreter.

### Checking numbers pt3

The checking of the token size (max 10 digits) and integer size (max 32 bits) was quite useless actually. It turns out the CPU will convert any arbitrary long string into a proper 32-bit number. It will overflow and just keep counting to make it fit. For example, the number `4294967295` will end up as `0xffffffff`, and the number `4294967296` will wrap around to `0x0`. I kind of like this because it's simple and moves the responsibility of keeping within the 32-bit limit to the end-user... to prevent _strange_ results such as numbers wrapping around.

In the future I may want to implement support for doubles or quads, but that's not necessary for the moment, so I just removed all the checks for the token string length and integer size.

So now, a signed token string such as "-2147483648" will convert perfectly to `-2147483648` (`0x80000000`) where as "-2147483649" will also convert perfectly to `2147483647` (`0x7fffffff`). As expected.

### Interpreter pt4

Now back to the `interpreter` as promised. In the _devlog 21_ I wrote that I would focus on _adding_ characters to the `TIB` this time. Let's do that.

First, in the `interpreter` loop, right after processing a `backspace`, I want to check for a `carriage return` (`\r` or `0x0D`). Clients sending characters over UART sometimes default to `\r\n`, sometimes to `\n`, and othertimes to `\r`. Our interpreter will act on `\n`, but we don't want `\r` to be part of a token so we'll do some little trickery for that:

```
    li t0, CHAR_CARRIAGE                        # load carriage return into temporary
    beq a0, t0, process_carriage                # process the carriage return if it matches
    j interpreter_tib

```

Here we jump to `process_carriage` if we detect a `\r` carriage return:

```
process_carriage:
    li a0, CHAR_NEWLINE     # convert a carriage return to a newline
    j interpreter_tib       # jump to add the character to the TIB
```

And in that case we'll simply replace the `\r` with a `\n`, before jumping to the `interpreter_tib` function, which is where we add the character to the `TIB`.

We'll load the `TIB_TOP` constant to a temporary register. This will allow us to track if/when the _TIB_ is full. Since we're not using interrupts or DMA or a circular buffer, it's a good idea to track the status of the buffer (`TOIN`) to ensure it's not full. If it's full we'll jump directly to an error handler, but later I'll define a different error handler for this use-case:

```
interpreter_tib:
    # add the character to the TIB
    li t4, TIB_TOP                              # load TIB_TOP memory address
    bge a1, t4, error                           # error if the terminal input buffer is full # FIXME: handle this better
```

Next we're going to add the character to the `TIB` and then increment the `TOIN` address value by 1:

```
    sb a0, 0(a1)                                # store the character from W register in the TIB
    addi a1, a1, 1                              # increment TOIN value by 1
```

Then, we want to check if the character is a `newline` and if yes then we'll jump to a procedure which processes it, otherwise jump back to the interpreter to continue processing characters:

```
    li t0, CHAR_NEWLINE                         # load newline into temporary
    beq a0, t0, process_token                   # process the token if it matches

    j interpreter                               # return to the interpreter if it's not a newline
```

The `process_token` function will first replace the stored `newline` with a `space`, because that's our separator when processing a token:

```
process_token:
    li a0, CHAR_SPACE       # convert newline to a space
    sb a0, -1(a1)           # replace previous newline character with space in W register
```

Notice we're storing the `space` character at offset `-1` because we incremented `TOIN` previously.. the `space` is there to _replace_ the previously stored `newline`.

Next we'll call the `token` function, which expects the load the buffer start address (`TIB`) in `W` (`a0`) and the buffer current address (`TOIN`) in the `X` (`a1`) working registers:

```
    # process the token
    mv a0, t2               # load the TIB address in the W working register
    call token              # read the token
```

Before we continue, let's test this!

```
make -B
/usr/bin/riscv64-linux-gnu-as -g -march=rv32imac  -o fiveforths.o fiveforths.s
/usr/bin/riscv64-linux-gnu-ld -m elf32lriscv -T fiveforths.ld -o fiveforths.elf fiveforths.o
/usr/bin/riscv64-linux-gnu-objcopy -O binary fiveforths.elf fiveforths.bin
/usr/bin/riscv64-linux-gnu-objcopy -O ihex fiveforths.elf fiveforths.hex
/usr/bin/riscv64-linux-gnu-objdump -D -S fiveforths.elf > fiveforths.dump
```

Then we'll load the debugger and upload the firmware:

```
make debug
/opt/riscv/bin/riscv64-unknown-elf-gdb -command=debug.gdb -q fiveforths.elf
Reading symbols from fiveforths.elf...
Info : accepting 'gdb' connection on tcp/3333
0x00000000 in ?? ()
Info : JTAG tap: riscv.cpu tap/device found: 0x1000563d (mfg: 0x31e (Andes Technology Corporation), part: 0x0005, ver: 0x1)
Info : JTAG tap: auto0.tap tap/device found: 0x790007a3 (mfg: 0x3d1 (GigaDevice Semiconductor (Beijing) Inc), part: 0x9000, ver: 0x7)
JTAG tap: riscv.cpu tap/device found: 0x1000563d (mfg: 0x31e (Andes Technology Corporation), part: 0x0005, ver: 0x1)
JTAG tap: auto0.tap tap/device found: 0x790007a3 (mfg: 0x3d1 (GigaDevice Semiconductor (Beijing) Inc), part: 0x9000, ver: 0x7)
(gdb) load
`/home/rock64/Desktop/code/forth/fiveforths/fiveforths.elf' has changed; re-reading symbols.
Info : JTAG tap: riscv.cpu tap/device found: 0x1000563d (mfg: 0x31e (Andes Technology Corporation), part: 0x0005, ver: 0x1)
Info : JTAG tap: auto0.tap tap/device found: 0x790007a3 (mfg: 0x3d1 (GigaDevice Semiconductor (Beijing) Inc), part: 0x9000, ver: 0x7)
Loading section .text, size 0x610 lma 0x8000000
Info : JTAG tap: riscv.cpu tap/device found: 0x1000563d (mfg: 0x31e (Andes Technology Corporation), part: 0x0005, ver: 0x1)
Info : JTAG tap: auto0.tap tap/device found: 0x790007a3 (mfg: 0x3d1 (GigaDevice Semiconductor (Beijing) Inc), part: 0x9000, ver: 0x7)
Start address 0x080001b0, load size 1552
Transfer rate: 565 bytes/sec, 1552 bytes/write.
```

Next let's add a breakpoint where we enter the `process_token` function and `token_done` just so we can inspect some registers and values in memory:

```
(gdb) break process_token
Breakpoint 16 at 0x8000602: file fiveforths.s, line 613.
(gdb) break token_done
Breakpoint 17 at 0x80000fe: file fiveforths.s, line 237.
```

And then we'll start the program:

```
(gdb) continue
Continuing.
```

In another terminal, I'll start sending characters to the terminal, followed by a CRLF (`\r\n`), and then single-step through it in gdb. A breakpoint will be hit as soon as the CRLF is received. Let's check the registers:

```
Breakpoint 16, 0x08000602 in process_token () at fiveforths.s:613
613	    checkchar CHAR_COMMENT_CPARENS, interpreter # check if character is a closing parens
(gdb) i r a0 a1 pc
a0             0xa	10
a1             0x20004d05	536890629
pc             0x8000602	0x8000602 <process_token>
```

Ok so the address of `a1` is `0x20004d05`, which means 5 characters were stored in the `TIB`. Let's see:

```
(gdb) x/5xb 0x20004d00
0x20004d00:	0x74	0x65	0x73	0x74	0x0a
```

There's our string: `test\n` .. but wait, didn't I send a `\r\n` ? Ah yes, since the `process_carriage` converts the `\r` to `\n`, what we're seeing is the first `\n` stored in the `TIB`. Let's step through it and inspect again:

```
(gdb) si
0x08000606	613	    checkchar CHAR_COMMENT_CPARENS, interpreter # check if character is a closing parens
(gdb) x/8xb 0x20004d00
0x20004d00:	0x74	0x65	0x73	0x74	0x20	0x00	0x00	0x00
```

Awesome! The `0x0a` (`newline`) was replaced by `0x20` (`space`), as expected. Now let's continue processing the token until the next breakpoint:

```
(gdb) c
Continuing.

Breakpoint 17, token_done () at fiveforths.s:237
237	    addi a0, a0, 1              # add 1 to W to account for TOIN offset pointer
(gdb) si
238	    mv a1, t2                   # store the size in X
(gdb) i r a0 a1 pc
a0             0x20004d01	536890625
a1             0x20004cff	536890623
pc             0x8000100	0x8000100 <token_done+2>
```

So here we can see a bug in `a0`. It looks like our `token_done` code was moving the token buffer start address by 1 but that's actually wrong. The correct address should be `0x20004d00`. Let's fix that and try again:

```
(gdb) s
239	    ret
(gdb) i r a0 a1 pc
a0             0x20004d00	536890624
a1             0x4	4
pc             0x8000100	0x8000100 <token_done+2>
```

Perfect! Now we have the correct start address in `a0` and the correct size `4` in `a1`.

OK so back to the code now. We want to perform similar bounds checks as we did in `COLON`, mainly checking if the string length is `0` or greater than `32`:

```
    # bounds checks on token size
    beqz a1, ok         # ok if token size is 0
    li t0, 32           # load max token size  (2^5 = 32) in temporary
    bgtu a1, t0, error  # error if token size is greater than 32
```

We can probably remove that bounds check from `DOCOL` now that we have it here, but let's save that for the optimization stage.

Next step is to hash the token before we can perform a dictionary lookup. Since we already have our values in `a0` and `a1`, we just need to call the hash function:

```
    # hash the token
    call djb2_hash
```

### Closing thoughts

This was a long session with a few bug fixes, but I can actually see the goal line now! In the next session I'll implement the lookup function to find the hashed word in the dictionary, and then it's "just" a matter of executing or compiling the word.
