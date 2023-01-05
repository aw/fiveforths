# January 04, 2023

1. [Log 32](#log-32)
2. [Fixing DSP](#fixing-dsp)
3. [Fixing macros](#fixing-macros)
4. [Fixing primitives](#fixing-primitives)
5. [Closing thoughts](#closing-thoughts)

### Log 32

In this session I'll focus on fixing some bugs I discovered with the data stack.

### Fixing DSP

In _devlog 2_, I introduced the idea of a `TOS` (top of stack) register. It's not new to **Forth**, but it was new to me. The idea was to use a saved register (`s3`) to keep the top element of the stack. It would slightly simplify certain operations but also complicate others.

One of the biggest issues I've run into is regarding the initialization routine, particularly this line:

```
    mv s3, zero                 # initialize TOS register
```

This sets the `TOS` register to a known value: `0`. So far so good, however let's take a look at our `PUSH` macro:

```
# push register to top of stack and move TOS to DSP
.macro PUSH reg
    addi sp, sp, -CELL  # move the DSP down by 1 cell
    sw s3, 0(sp)        # store the value in the TOS to the top of the DSP
    mv s3, \reg         # copy register into TOS
.endm
```

It first decrements the `DSP` (`sp`) pointer by 1 CELL before storing the `TOS` value into it, and then copying whatever register was pushed.

Here's an example:

```
PUSH a0
```

Seems simple, but it's bad. The very first `PUSH` will actually end up copying the value `0` to the top of the `DSP` (pointed at by `sp`, which will be address `0x20004FFC`), and it will store the value from `a0` into `TOS` (`s3`). So now, our stack actually has 2 elements! Oops!! In fact, the very first `PUSH` should only write to `TOS` without moving the stack pointer... thus ignoring the `0` in the `TOS`, but I think coding for that condition is a bit ridiculous because the `TOS` could potentially have a value we want, ex: if `0=` was the first command, then `TOS` would contain `1`...

So, at this point I just want to get rid of the `TOS` (`s3`) register and only use the `DSP`. The entire time I've always had to think extra hard about the `TOS` register and now that I've encountered this bug, I just want it to disappear.

### Fixing macros

To start, I'll edit the macros in `src/02-macros.s` to only use the `DSP`. Here are the changes to the `POP` macro:

```
 .macro POP reg
-    mv \reg, s3         # copy TOS to register
-    lw s3, 0(sp)        # load DSP value to register
+    lw \reg, 0(sp)      # load DSP value to register
     addi sp, sp, CELL   # move the DSP up by 1 cell
 .endm
```

and the `PUSH` macro:

```
 .macro PUSH reg
     addi sp, sp, -CELL  # move the DSP down by 1 cell
-    sw s3, 0(sp)        # store the value in the TOS to the top of the DSP
-    mv s3, \reg         # copy register into TOS
+    sw \reg, 0(sp)      # store the value in the register to the top of the DSP
 .endm
```

The above macros were simplified thanks to the removal of the `TOS`. Similarly, we'll also adjust the `PUSHVAR` macro (which I think I coded incorrectly anyways):

```
 .macro PUSHVAR var
     addi sp, sp, -CELL  # move the DSP down by 1 cell
-    sw s3, 0(sp)        # store the value in the TOS to the top of the DSP
     li t0, \var         # load variable into temporary
-    lw s3, 0(t0)        # load variable address value into TOS
+    sw t0, 0(sp)        # store the variable value to the top of the DSP
 .endm
```

Here we're not loading the value pointed at by the variable anymore. Instead we're just storing the memory address of the variable to the top of the stack. I guess we can then use `@` to fetch the actual contents of those memory addresses.

### Fixing primitives

That conveniently leads us to our next changes in `src/08-forth-primitives.s`, where we'll start by modifying `FETCH`:

```
 defcode "@", 0x0102b5e5, FETCH, NULL
-    lw s3, 0(s3)        # load address value from TOS (addr) into TOS (x)
+    lw t0, 0(sp)        # load the top of stack into temporary
+    lw t0, 0(t0)        # load the value from the temporary (addr)
+    sw t0, 0(sp)        # store the value back the top of stack (x)
     NEXT
```

Yikes! We've got way more instructions for this, because now we need to load the value in the stack pointer, get the address it points to, then store that back into the stack pointer. Slightly more complicated than simply loading from `TOS` into `TOS`.

We can test that it works in the terminal with:

```
latest @<Enter>
```

Now if everything worked well, we should have the memory address of `word_SEMI` stored as the first entry in the data stack. Let's check with `GDB`:

```
(gdb) i r sp
sp             0x20004ffc	0x20004ffc
(gdb) x/xw 0x20004ffc
0x20004ffc:	0x080004d8
(gdb) x/xw 0x080004d8
0x80004d8 <word_SEMI>:	0x080004cc
```

**Great!**

Next we'll modify `STORE` by loading the top two stack entries into temporaries, and then storing one into the other:

```
 defcode "!", 0x0102b5c6, STORE, FETCH
     lw t0, 0(sp)        # load the DSP value (x) into temporary
-    sw t0, 0(s3)        # store temporary into address stored in TOS (addr)
-    lw s3, CELL(sp)     # load second value in DSP to TOS
+    lw t1, CELL(sp)     # load the DSP value (addr) into temporary
+    sw t0, 0(t1)        # store x into addr
     addi sp, sp, 2*CELL # move DSP up by 2 cells
     NEXT
```

The instruction count remains the same, but we're not messing with `TOS` anymore. Let's test it out by trying to store the value of `latest` to the writeable memory address `HERE`, which is set to `0x20000000` (the start of the dictionary) on initialization. In the terminal we'll type:

```
here @ latest @ !<Enter>
```

Still following along? We just put `HERE` in the stack, and then put `LATEST` in the stack. Then we called `STORE` which technically should _store_ `0x080004d8` into `0x20000000`. Let's check with `GDB`:

```
(gdb) x/xw 0x20000000
0x20000000:	0x080004d8
```

**Sweet!**

Actually, at this point I'm starting to feel amazing. So far everything is working as I hoped. Let's continue with `ZEQU`, which was a buggy non-sensical little 1-liner:

```
 defcode "0=", 0x025970b2, ZEQU, RSPFETCH
-    seqz s3, s3         # store 1 in TOS if TOS is equal to 0, otherwise store 0
+    lw t0, 0(sp)        # load the DSP value (x) into temporary
+    snez t0, t0         # store 0 in temporary if it's equal to 0, otherwise store 1
+    addi t0, t0, -1     # store -1 in temporary if it's 0, otherwise store 0
+    sw t0, 0(sp)        # store value back into the top of the stack
     NEXT
```

First I realized the `ZEQU` should actually store `-1` not `1`. In this case I'm using the exact same approach as _sectorforth_ but with RISC-V instructions to "set if not equal" and then to decrement the value by 1. Let's test it by storing the `STATE` (should be `0`) in the `DSP`, and then calling `0=` in the terminal with:

```
state @ 0=<Enter>
```

In `GDB` we should find `-1` as the top stack value:

```
(gdb) i r sp
sp             0x20004ffc	0x20004ffc
(gdb) x/dw 0x20004ffc
0x20004ffc:	-1
```

Now let's call `0=` again in the terminal:

```
0=<Enter>
```

And let's inspect it again in `GDB`:

```
(gdb) i r sp
sp             0x20004ffc	0x20004ffc
(gdb) x/dw 0x20004ffc
0x20004ffc:	0
```

**Awesome!**

The last primitives to fix are `ADD` and `NAND` which should be fairly similar as they have the same stack effects. Let's start with `ADD`:

```
 defcode "+", 0x0102b5d0, ADD, ZEQU
     POP t0              # pop value into temporary
-    add s3, s3, t0      # add values and store in TOS
+    lw t1, 0(sp)        # load DSP value (x2) into temporary
+    add t0, t0, t1      # add the two values
+    sw t0, 0(sp)        # store the value into the top of the stack
```

Again, without the `TOS` it's a bit more complex. Here we're still popping the top value from the stack into `t0`, but we're also loading the next top value into `t1` (note: the `POP t0` moves the stack pointer, so we're still loading from offset `0`). Afterwards we're adding the two registers and then storing the result back into the top of the stack.

Now let's look at the bitwise `NAND`:

```
 defcode "nand", 0x049b0c66, NAND, ADD
     POP t0              # pop value into temporary
-    and s3, s3, t0      # store bitwise AND of temporary and TOS into TOS
-    not s3, s3          # store bitwise NOT of TOS into TOS
+    lw t1, 0(sp)        # load DSP value (x2) into temporary
+    and t0, t0, t1      # perform bitwise AND of the two values
+    not t0, t0          # perform bitwise NOT of the value
+    sw t0, 0(sp)        # store the value into the top of the stack
     NEXT
```

It's almost identical to `ADD` except we're performing bitwise _AND_ and _NOT_ instead of _ADD_.

That completes our changes to the _forth primitives_. Let's test `ADD` and `NAND`. We'll start by trying to add the value of `LATEST` to the value of `LATEST`. In the terminal we'll type:

```
latest @ latest @ +<Enter>
```

Now in `GDB`, let's get the address of `LATEST` (aka `word_SEMI`), right now it gives us `0x80004e8` (because we added some new instructions previously). Multiplying it by 2 should give us `0x100009D0` stored at the top of the stack.

Let's check:

```
(gdb) x/xw word_SEMI
0x80004e8 <word_SEMI>:	0x080004dc
(gdb) i r sp
sp             0x20004ffc	0x20004ffc
(gdb) x/xw 0x20004ffc
0x20004ffc:	0x100009d0
```

**Perfect!**

Next we'll see if `NAND` works as expected by storing `STATE` in the top of the stack. In the terminal we'll type:

```
state @ state @ nand<Enter>
```

And in `GBD`, since we know that `STATE` is set to `0` when we're in _execute_ mode, performing a `NAND` of `0` and `0` should give us `-1` (remember this is bitwise, which flips all the 0 bits to 1, giving us `0xFFFFFFFF` or `-1`):

```
(gdb) i r sp
sp             0x20004ffc	0x20004ffc
(gdb) x/dw 0x20004ffc
0x20004ffc:	-1
```

**Yesss!!!**

That's all for our _forth primitives_. The one final change is to remove the initialization of `s3` in `src/06-initialization.s`:

```
-    mv s3, zero                 # initialize TOS register
```

### Closing thoughts

This was a rather long session of writing and testing and editing code, but we did it! Not only did I fix some bugs in some of the primitives, but I also greatly simplified the data stack by getting rid of the `TOS`.

In the next session, I'll get the compiler working so I can finally add words to the user dictionary starting at address `0x20000000` (on the longan nano).
