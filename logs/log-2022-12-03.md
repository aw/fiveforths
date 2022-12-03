# December 3, 2022

1. [Log 12](#log-12)
2. [Fixing COLON](#fixing-colon)
3. [Starting SEMI](#starting-semi)
4. [Continuing SEMI](#continuing-semi)
5. [Completing SEMI](#completing-semi)
6. [Setup registers](#setup-registers)
7. [Closing thoughts](#closing-thoughts)

## Log 12

Thanks to [Moving Forth](https://www.bradrodriguez.com/papers/moving1.htm), I finally understand how `COLON` works, and the purpose of `docol` and `enter`. Let's fix this.

### Fixing COLON

In the last session I couldn't figure out if I needed `docol` or `enter` as the codeword. When I put the two functions side-by-side, I realized they are almost identical! My `docol` was using the `PUSHRSP` macro, so I expanded it below:

```
docol:
    addi s2, s2, -CELL  # decrement RSP by 1 cell
    sw s1, 0(s2)        # store value from register into RSP
    addi s1, a0, CELL   # skip code field in W by adding a CELL, store it in IP
    NEXT

enter:
    sw s1, 0(s2)        # store memory address from IP into RSP
    addi s2, s2, CELL   # increment RSP by CELL size
    addi s1, a0, CELL   # increment IP by W + CELL size
    NEXT
```

After some analysis and brief testing, I concluded that `docol` is in fact the correct implementation. The `enter` function is an exact copy from _derzforth_, and it's wrong because it first writes to the return stack **before moving the pointer**. In my Forth implementation, it points to the last entry in the stack, not the next available entry, similar to _sectorforth_ and _jonesforth_, and the stack grows downward not upwards. So we first need to decrement the return stack pointer `RSP` before storing the new value. I want to store the code in the `Y` (`a2`) working register, so let's adjust `COLON`:

```
-    la t2, enter        # load the codeword address into temporary # FIXME: enter or docol?
+    la a2, docol        # load the codeword address into Y working register
```

I also want to remove the hardcoded CELL sizes in `COLON` and make sure we store the codeword from `Y`:

```
     # build the header in memory
-    sw t4, 0(t3)        # store the address of the previous word
-    sw a0, 4(t3)        # store the hash
-    sw t2, 8(t3)        # store the codeword address
+    sw t4, 0*CELL(t3)   # store the address of the previous word
+    sw a0, 1*CELL(t3)   # store the hash
+    sw a2, 2*CELL(t3)   # store the codeword address

     # update HERE variable
-    addi t3, t3, 12     # move the HERE pointer to the end of the word
+    addi t3, t3, 3*CELL # move the HERE pointer to the end of the word
```

Our new `docol` implementation will look like this:

```
docol:
    PUSHRSP s1          # push IP onto the return stack
    addi s1, a2, CELL   # skip code field in Y by adding a CELL, store it in IP
    NEXT
```

### Starting SEMI

With `:` out of the way, I can focus on `;` next. I'll start by adjusting the hash of `SEMI`. It's currently set to `0x0102b5e0` but since it's an immediate word which must be executed right away, even if the `STATE` is set to 1 (compile mode), I'll need to add the `F_IMMED` flag to the MSB by setting it to 1 (bitwise _OR_ with `0x80000000`).

```
-defcode ";", 0x0102b5e0, SEMI, COLON
+defcode ";", 0x8102b5e0, SEMI, COLON
```

This could lead to some confusion down the road, so I'll document the 32-bit hash value below:

```
             32-bit hash
+-------+--------+------------------+
| FLAGS | LENGTH |      HASH        |
+-------+--------+------------------+
 3-bits  5-bits   24-bits

```

That's the actual layout of the 32-bit hash. The first 3 bits represent flags, from the MSB: `IMMEDIATE, HIDDEN, USER-DEFINED`. The next 5 bits represent the length of the token. In our case we set it to 5 bits, which means it can have a maximum 32 characters (`2^5`). The remaining 24 bits represent the actual hash of the token.

In the `djb2_hash` function we're performing a bitwise _AND_ with the mask `0x00ffffff` which lets us clear the first 8 bits in the hash. Then we add the length (shifted left by 24 bits) using a bitwise _OR_.

For example, the word `exit` should technically hash to `0x7c967e3f`, but we clear the first 8 bits and it becomes `0x00967e3f`, then we add the shifted length (4) and it becomes: `0x04967e3f`.

### Continuing SEMI

Moving forward with `SEMI`, at this point we're essentially ending the compilation of the word. We'll need to clear the `HIDDEN` flag, store the codeword for `exit` in memory, then move the `HERE` pointer.

Clearing `HIDDEN` will first require loading the hash from memory. We use `LATEST` to find out where it's stored:

```
    li t0, LATEST       # copy the memory address of LATEST into temporary
    lw t0, 0(t0)        # load the address value into temporary
    lw t1, 4(t0)        # load the hash into temporary
```

Then we'll load a bitmask used to unset the hidden bit (it's the bitwise _NOT_ of the hidden flag `0x40000000`):

```
    li t2, 0xbfffffff   # load hidden flag into temporary (~F_HIDDEN)
```

Then we can proceed to unhiding, or revealing the word and writing it back to memory:

```
    and t1, t1, t2      # unhide the word
    sw t1, 4(t0)        # write the hash back to memory
```

### Completing SEMI

The final steps in the semicolon primitive are to update the `HERE` variable, move the `HERE` pointer to the end of the word definition, and return the interpreter's `STATE` to 0, which is _execute_ mode instead of _compile_ mode.

First we'll load the address of `HERE` and update it with the address of the `exit` codeword:

```
    # update HERE variable
    li t0, HERE         # copy the memory address of HERE into temporary
    la t1, code_EXIT    # load the codeword address into temporary # FIXME: why not body_EXIT?
    sw t1, 0(t0)        # store the codeword address into HERE
```

Notice I've got another question mark regarding loading the `exit` codeword. Looking at _derzforth_ shows that it should jump at `code_EXIT` but I'm wondering if it shouldn't be `body_EXIT` or `word_EXIT`. I'll need to read more about this first.

For now I'll just continue and move the `HERE` pointer:

```
    # move HERE pointer
    addi t1, t1, CELL   # move the HERE pointer by 1 CELL
    sw t1, 0(t0)        # store the new address of HERE into the HERE variable
```

And finally, we update the `STATE` variable:

```
    # update the STATE variable
    li t0, STATE        # load the address of the STATE variable into temporary
    sw zero, 0(t0)        # store the current state (0 = execute) back into the STATE variable
```

That's almost identical to what we did in `COLON` except we set it to 0 instead of 1.

### Setup registers

Now I want to initialize some registers in the `_start` function so I can get to testing the `.elf` and `.bin` files.

First we initialize the stack pointers:

```
    la sp, __stacktop   # initialize DSP register
    la s1, interpreter  # initialize IP register
    li s2, RSP_TOP      # initialize RSP register
    mv s3, zero         # initialize TOS register
```

I set the IP register (`s1`) to point to the `interpreter`, but that might need to change.

Then we ensure the function parameter registers are initialized to zero:

```
    mv a0, zero         # initialize W register
    mv a1, zero         # initialize X register
    mv a2, zero         # initialize Y register
    mv a3, zero         # initialize Z register
```

Next we'll store some values in the variables:

```
    li t0, STATE        # load STATE variable
    sw zero, 0(t0)      # initialize STATE variable (0 = execute)
```

A nifty shortcut here, since `zero` is a register (`x0`), we can write it directly to a memory address without first needing to load it to a temporary like `li t0, 0`.

We'll need to set `TOIN` to the same address as `TIB`, basically the terminal input buffer's current "in" location will be the start of the buffer:

```
    li t0, TIB          # load TIB memory address
    li t1, TOIN         # load TOIN variable
    sw t0, 0(t1)        # initialize TOIN variable to contain TIB start address
```

Next we'll need to set `HERE` to be the same address as the start of the `RAM` because there's nothing stored there yet:

```
    li t0, RAM_BASE     # load RAM_BASE memory address
    li t1, HERE         # load HERE variable
    sw t0, 0(t1)        # initialize HERE variable to contain RAM_BASE memory address
```

Finally, we'll make sure `LATEST` points to the latest dictionary word we defined (`SEMI`):

```
    la t0, word_SEMI    # load address of the last word in Flash memory (;) for now
    li t1, LATEST       # load LATEST variable
    sw t0, 0(t1)        # initialize LATEST variable to contain word_SEMI memory address
```

That completes my Forth initialization routine, but I'm  not even sure if it's correct. I am however certain it will change in the future because some of those values will also need to be initialized when there's an error.

### Closing thoughts

I believe the next step after initialization is for the code to jump to the interpreter, but that has yet to be written! (and I'm not even sure!) In the next session, I'll focus on testing what I've written so far, directly on the Longan Nano Lite. Then I'll jump to the 2 missing primitives: `key` and `emit` - for IO.
