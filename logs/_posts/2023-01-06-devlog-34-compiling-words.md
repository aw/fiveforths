# January 06
1. [Log 34](#log-34)
2. [Printing strings](#printing-strings)
3. [Rebooting the MCU](#rebooting-the-mcu)
4. [Compiling words](#compiling-words)
5. [Closing thoughts](#closing-thoughts)

### Log 34

In this session I will work on compiling words, but before that I want to add 2 new features to my Forth: _printing strings_ and _rebooting the mcu_.

### Printing strings

The previous approach to printing strings over the UART was to repeat the same 2 lines of code for every character. To print ` ok\n` we would write this:

```
 ok:
    li a0, CHAR_SPACE
    call uart_put
    li a0, 'o'
    call uart_put
    li a0, 'k'
    call uart_put
    li a0, CHAR_NEWLINE
    call uart_put
```

This works fine for short strings, but it's quite bothersome and ugly for longer strings.

Here's my short implementation of a UART "print" function:

```
uart_print:
    mv s3, ra                   # save the return address
uart_print_loop:
    beq a1, a2, uart_print_done # done if we've printed all characters
    lbu a0, 0(a1)               # load 1 character from the message string
    call uart_put
    addi a1, a1, 1              # increment the address by 1
    j uart_print_loop           # loop to print the next message
uart_print_done:
    mv ra, s3                   # restore the return address
    ret
```

It accepts 2 arguments:

* `a1` which contains the memory address of the start of a string (I'll show an example later).
* `a2` which contains the address of the string + its length.

The `uart_print` starts by saving the `ra` register and ends by restoring it. We do this because the `call uart_put` would otherwise clobber `ra` and it would be unable to return after printing.

The `uart_print_loop` simply loops over each character in the string, printing a character at each iteration. It increments the string's address (`a1`) until it's the same as `a2`.

Here's how we would use it instead of the above `ok` function:

```
ok:
    la a1, msg_ok       # load string message
    addi a2, a1, 6      # load string length
    call uart_print     # call uart print function
```

And we could define the `msg_ok` string like this:

```
msg_ok: .ascii "   ok\n"
```

Note the `.ascii` string is _NOT_ null terminated, and it must be aligned to 2 bytes. In other words a 3 or 5 byte string would not work.

Let's do something similar to `error`:

```
error:
    la a1, msg_error    # load string message
    addi a2, a1, 4      # load string length
    call uart_print     # call uart print function
```

And define the `msg_error` like this:

```
msg_error: .ascii "  ?\n"
```

### Rebooting the MCU

I often find myself wanting to test a _clean slate_ of the Forth, without physically resetting the device (which requires restarting openocd and gdb). So I decided to add a new primitive called `reboot`, which jumps directly to the `_start` initialization procedure:

```
# reboot ( -- )         # Reboot the entire system and initialize memory
defcode "reboot", 0x06266b70, REBOOT, NULL
    j reboot            # jump to reboot
```

I then had to modify `FETCH` to link to `REBOOT` instead of `NULL`:

```
-defcode "@", 0x0102b5e5, FETCH, NULL
+defcode "@", 0x0102b5e5, FETCH, REBOOT
```

Now let's define the `reboot` function:

```
reboot:
    la a1, msg_reboot   # load string message
    addi a2, a1, 12     # load string length
    call uart_print     # call uart print function
    j _start            # reboot when print returns
```

It's pretty much the same as `ok` and `error`, with a different string message and different jump to address. Here's the message:

```
msg_reboot: .ascii "  rebooting\n"
```

So now typing `reboot<Enter>` in the terminal will display the string `rebooting` and everything will be reset as if we first booted the device. Of course I realize this might be problematic once interrupts are enabled, but I think by then I'll be able to remove this primitive and functionality.

### Compiling words

Now the final missing element of this **Forth**, _compiling words_!!

The first change is to fix some minor issues in our macros. In 3 macros we're decrementing the `sp` stack pointer by 1 CELL _before_ performing an operation, which is fine except when that operation involves the `sp` pointer. Let's change the `PUSH` macro first, and I'll explain the difference afterwards:

```
 .macro PUSH reg
+    sw \reg, -CELL(sp)  # store the value in the register to the top of the DSP
     addi sp, sp, -CELL  # move the DSP down by 1 cell
-    sw \reg, 0(sp)      # store the value in the register to the top of the DSP
 .endm
```

Here we moved the `sw` instruction so it's performed first, before decrementing the pointer. But we're also storing it at the `-4` offset. This was necessary for something like `PUSH sp` to work, where we want to push the current `sp` address not the next address (`sp - 4`).

We'll make a similar change to `PUSHRSP`:

```
 .macro PUSHRSP reg
+    sw \reg, -CELL(s2)  # store value from register into RSP
     addi s2, s2, -CELL  # decrement RSP by 1 cell
-    sw \reg, 0(s2)      # store value from register into RSP
 .endm
```

And finally we'll also modify `PUSHVAR` to load the register and then store it in `sp - 4` before moving the `sp` pointer down by 1 CELL.

```
 .macro PUSHVAR var
-    addi sp, sp, -CELL  # move the DSP down by 1 cell
     li t0, \var         # load variable into temporary
-    sw t0, 0(sp)        # store the variable value to the top of the DSP
+    sw t0, -CELL(sp)    # store the variable value to the top of the DSP
+    addi sp, sp, -CELL  # move the DSP down by 1 cell
 .endm
```

In the `COLON` primitive (inner interpreter), we need to do the _exact same thing_ as in `process_token` (outer interpreter) before and after calling `token`, so let's replace the existing code:


```
 defcode ":", 0x0102b5df, COLON, LATEST
-    li a0, TIB          # load TIB into W
-    li t3, TOIN         # load the TOIN variable into unused temporary register
-    lw a1, 0(t3)        # load TOIN address value into X working register
+    li t3, TOIN         # load TOIN variable into unused temporary register
+    lw a0, 0(t3)        # load TOIN address value into temporary
     call token          # read the token

+    # move TOIN
+    add t0, a0, a1      # add the size of the token to TOIN
+    sw t0, 0(t3)        # move TOIN to process the next word in the TIB
+
     # bounds checks on token size
-    beqz a1, error      # error if token size is 0
+    beqz a1, ok         # ok if token size is 0
     li t0, 32           # load max token size  (2^5 = 32) in temporary
     bgtu a1, t0, error  # error if token size is greater than 32

-    # store the word then hash it
-    sw a0, 0(t3)        # store new address into TOIN variable
     call djb2_hash      # hash the token
```

Now `COLON`'s first few lines are identical to `process_token`.

We'll also need to fix a bug I discovered when storing the `code_EXIT` address at the end of a word:

```
-    sw t1, 0(t0)        # store the codeword address into HERE
+    sw t1, 0(t2)        # store the codeword address into HERE
```

The actual `HERE` address was stored in `t2` but I accidentally used `t0` which means `EXIT` would not be written to the correct memory location.

Now let's look at our `compile` function, called from the `process_token` (outer interpreter). The first step is to find the codeword address, which is 2 CELLs down:

```
compile:
    addi t0, a1, 2*CELL     # increment the address of the found word by 8 to get the codeword address
```

Then we'll load `HERE` into a temporary, and store the codeword in there:

```
    li t1, HERE             # load HERE variable into temporary
    lw t2, 0(t1)            # load HERE value into temporary
    sw t0, 0(t2)            # write the address of the codeword to the current definition
```

Afterwards we can increment `HERE` by 1 CELL and store its value back, before jumping back to process the next token:

```
    addi t0, t2, CELL       # increment HERE by 4
    sw t0, 0(t1)            # store new HERE address
compile_done:
    j process_token
```

**That's it!**

At least.. I think that's it. Let's try to compile a word in the terminal:

```
: dup sp@ @ ;<Enter>  ok
```

So far so good, maybe? Let's check the user dictionary with `GDB`. This should store 6 values in memory starting from `0x20000000`, three values for `dup` (link, hash, codeword), one address for `sp@` (`DSPFETCH`), one address for `@` (`FETCH`) and one address for `exit` (`code_EXIT`):

```
(gdb) x/6xw 0x20000000
0x20000000:	0x08000650	0x03886bce	0x080003f4	0x080005b0
0x20000010:	0x08000598	0x080005ec
```

Now let's look at each value:

```
(gdb) x/xw 0x08000650
0x8000650 <word_SEMI>:	0x08000644
```

That's our link to the previous word. Then `0x03886bce` is the hash of the word `dup`.

```
(gdb) x/xw 0x080003f4
0x80003f4 <.addr>:	0x080003e4
(gdb) x/xw 0x080003e4
0x80003e4 <docol>:	0xfe992e23
```

Next we have the address of `.addr` which points to `docol`. This is where I'm still a bit confused, and it might be totally wrong.

Next let's examine the remaining 3 values:

```
(gdb) x/xw 0x080005b0
0x80005b0 <code_DSPFETCH>:	0x08000284
(gdb) x/xw 0x08000598
0x8000598 <code_FETCH>:	0x08000264
(gdb) x/xw 0x080005ec
0x80005ec <code_EXIT>:	0x080002d4
```

All that looks pretty good to me. Let's store a value in the stack, and then use `dup` to duplicate it on the stack (which is what `sp@ @` does):

```
456 dup<Enter>
```

...crash

Well... I guess that doesn't work. The word was definitely _compiled_ and stored in memory, but there's clearly something wrong in there. I have a feeling this might be related to the compiled `.addr -> docol` address, but I'm not sure.

### Closing thoughts

In the next session I'll manually step through the execution of my newly defined `dup` word, and see if I can find the problem. Hopefully I'll be able to fix this in the next session, and then I'll have a fully functional **Forth**. Yay!
