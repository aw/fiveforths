# November 21, 2022

1. [Simpler code](#simpler-code)
2. [Log 6](#log-6)
3. [Cleanup the Makefile](#cleanup-the-makefile)
4. [Sorting primitives](#sorting-primitives)
5. [Defining new words](#defining-new-words)
6. [Stack pointer and top of stack](#stack-pointer-and-top-of-stack)
7. [Reviewing primitives](#reviewing-primitives)
8. [Closing Thoughts](#closing-thoughts)

## Simpler code

Before adding new words to the Assembly file (`fiveforths.s`), I thought it would be a good idea to cleanup and simplify a few things.

### Log 6

The `Makefile` was my first target, where I remove a bunch of redundant text and replaced them with some wildcards.

#### Cleanup the Makefile

A few of the lines were changed to look something like this:

```
+PROGNAME = fiveforths
-fiveforths.elf:
-               $(LD) -m $(EMU) -T fiveforths.ld -o $@ fiveforths.o
+%.elf: %.o
+               $(LD) -m $(EMU) -T $(PROGNAME).ld -o $@ $<
```

#### Sorting primitives

Since this Forth begins life with a small set of primitives, I decided to sort them based on their functionality. The first section contains words 8 primitive words:

* `@ ! sp@ rp@ 0= + nand exit`

Which are followed by 2 input/output words:

* `key emit`

Next we'll find 5 variables:

`state tib >in here latest`

And finally the last two words for defining new words:

`: ;`

#### Defining new words

At the moment, the missing (undefined) words are `>in key emit : ;`. Of course we're also missing some functions to handle I/O but we'll get to that later.

Here i'll start with the `>in` variable, aka `TOIN`. Its job is to give a look into the `TIB` - _terminal input buffer_ so we can know where we are in the buffer (ex: when reading a line of text). Here is the code defintion:

```
defcode ">in", 0x0387c89a, TOIN, STATE
    PUSH s3             # push TOS to top of data stack
    li t0, TOIN         # load address value from TOIN into temporary
    lw s3, 0(t0)        # load temporary into TOS
    NEXT
```

and the macro-expanded version:

```
    .section .rodata
    .balign 4           # align to CELL bytes boundary
    .globl word_TOIN
  word_TOIN :
    .4byte word_STATE   # 32-bit pointer to codeword of link
    .4byte 0x0387c89a   # 32-bit hash of this word
    .globl code_TOIN
  code_TOIN :
    .4byte body_TOIN    # 32-bit pointer to codeword of label
    .balign 4           # align to CELL bytes boundary
    .text
    .balign 4           # align to CELL bytes boundary
    .globl body_TOIN
  body_TOIN :           # assembly code below
    addi sp, sp, -4     # decrement DSP by 4 bytes (32-bit aligned)
    sw s3, 0(sp)        # store value from register into DSP
    li t0, TOIN         # load address value from TOIN into temporary
    lw s3, 0(t0)        # load temporary into TOS

    lw a0, 0(s1)        # load memory address from IP into W
    addi s1, s1, 4      # increment IP by CELL size
    lw t0, 0(a0)        # load memory address from W into temporary
    jr t0               # jump to the address in temporary
```

I already noticed some issues here, which I'll explain below.

#### Stack pointer and top of stack

While reading [Stack Computers: The New Wave (Koopman, 1989)](https://www.goodreads.com/book/show/20507605-stack-computers), I had the idea of using a `TOS` (`s3/x19` register) as the top of the stack register. The top item in the stack would always be directly accessible in `s3` instead of a memory address pointed to by the data stack pointer `DSP` (`sp/x2` register). This should theoretically make it much quicker to work on data that is in the `TOS`, since there's no need to "juggle" the `DSP`.

However when I look at the code, it seems I'm still moving the `DSP` around (for no reason) in certain places.

I also think I should probably dedicate a second register for this, let's call it `SOS` (`s4/x20` register) to act as the "second top of stack" register.

#### Reviewing primitives

With the above in mind, let's review the existing primitives, and make sure my understanding of these registers is correct.

```
@ ( addr -- x )       Fetch memory at addr
```

This `FETCH` primitive is designed to "fetch" a value from the top of the stack (a memory address), and then store the value referenced at the memory address, back into the top of the stack:

```
defcode "@", 0x0102b5e5, FETCH, NULL
    lw s3, 0(s3)        # load address value from TOS into TOS
    NEXT
```

Thanks to our `TOS` register (`s3`), we can perform this operating with just 1 instruction. Let's keep going.

```
! ( x addr -- )       Store x at addr
```

This `STORE` primitive is designed to "store" a value into a memory address. It also moves the lower two `DSP` values into `SOS` and `TOS`, and increases the `sp` by 2 cells:

```
defcode "!", 0x0102b5c6, STORE, FETCH
    sw s4, 0(s3)        # store value from SOS into memory address stored in TOS
    lw s4, 4(sp)		# load second stack element from DSP into SOS
    lw s3, 0(sp)		# load first stack element from DSP into TOS
    addi sp, sp, 8      # increment DSP by 2 cells (32-bit aligned)
    NEXT
```

This code looks awfully familiar! In fact, it's just like the `POP` macro, except it works on 2 registers instead of 1. Let's think about this some more... if popping the `TOS` and `SOS`, we can save one instruction by decreasing the `sp` by 8 instead of 4, as shown above.

In this case, let's add new macro called `DUALPOP` as shown above I think this might be a common operation:

```
.macro DUALPOP reg1, reg2
    lw \reg2, 4(sp)     # load second stack element from DSP into register 2
    lw \reg1, 0(sp)     # load first stack element from DSP into register 1
    addi sp, sp, 8      # increment DSP by 2 cells (32-bit aligned)
.endm
```

Then we can replace the above `STORE` primitive with:

```
defcode "!", 0x0102b5c6, STORE, FETCH
    sw s4, 0(s3)        # store value from SOS into memory address stored in TOS
    DUALPOP s3, s4      # pop first and second top of stack data registers into TOS and SOS
    NEXT
```

#### Closing Thoughts

This was a rather long session with lots of changes, but I'm happy it's moving along. In the next session, I'll continue reviewing the other primitives such as `sp@` and `rp@`, because I'm certain they don't work as expected anymore with the `TOS` and `SOS` registers.
