# November 24, 2022

1. [Reviewing primitives again](#reviewing-primitives-again)
2. [Log 8](#log-8)
3. [Simple fixes](#simple-fixes)
5. [Reviewing variables](#reviewing-variables)
6. [Closing Thoughts](#closing-thoughts)

## Reviewing primitives again

Continuing from the last session, I'll look at the primitives and see what needs to be adjusted.

### Log 8

In this session, I want to fix the remaining `# OK` primitives.

#### Simple fixes

We'll begin by looking at `ZEQU`:

```
# 0= ( x -- f )         1 if top of stack is 0, 0 otherwise
defcode "0=", 0x025970b2, ZEQU, RSPFETCH
    seqz s3, s3         # store 1 in TOS if TOS is equal to 0, otherwise store 0
    NEXT
```

This is a very short primitive because it only works on the `TOS` register. RISC-V's pseudo-instruction `seqz` is very useful in this case for checking if the `TOS` is equal to zero. Next, we'll look at the `ADD` primitive, which takes the `TOS` and top of the `DSP`, moves the `DSP` pointer up by 1 cell and stores the result in the `TOS`.

```
# + ( x1 x2 -- n )      Add the two values at the top of the stack
defcode "+", 0x0102b5d0, ADD, ZEQU
    addi sp, sp, CELL   # move the DSP up by 1 cell
    lw t0, -CELL(sp)    # load value to temporary
    add s3, s3, t0      # add values and store in TOS
    NEXT
```

Part of the above operation looks very similar to a `POP`, so we'll move that to a macro:

```
# pop top of stack to register
.macro POP reg
    addi sp, sp, CELL   # move the DSP up by 1 cell
    lw \reg, -CELL(sp)  # load DSP value to temporary
.endm

# + ( x1 x2 -- n )      Add the two values at the top of the stack
defcode "+", 0x0102b5d0, ADD, ZEQU
    POP t0              # pop value into temporary
    add s3, s3, t0      # add values and store in TOS
    NEXT
```

The following primitive, bitwise `NAND`, built from RISC-V's `and` and `not` instructions (similar to `&` and `~` in C). 

This is simplified below:

```
# nand ( x1 x2 -- n )   bitwise NAND the two values at the top of the stack
defcode "nand", 0x049b0c66, NAND, ADD
    POP t0              # pop value into temporary
    and s3, s3, t0      # store bitwise AND of temporary and TOS into TOS
    not s3, s3          # store bitwise NOT of TOS into TOS
    NEXT
```

Finally, the `EXIT` primitive restores the address at the top of the return stack into the instruction pointer `IP`:

```
# exit ( r:addr -- )    Resume execution at address at the top of the return stack
defcode "exit", 0x04967e3f, EXIT, NAND
    POPRSP s1           # pop RSP into IP
    NEXT
```

#### Reviewing variables

The 5 variables `TIB STATE TOIN HERE LATEST` are almost identical, where we simply want move the current `TOS` to the top of the `DSP`, and then load the address stored in the variable to the `TOS`. That's basically a `PUSH` operation so we'll define a new macro `PUSHVAR` for that:

```
# push variable to top of stack
.macro PUSHVAR var
    sw s3, -CELL(sp)    # store the value in the TOS to the top of the DSP
    li t0, \var         # load variable into temporary
    lw s3, 0(t0)        # load variable address value into TOS
    addi sp, sp, -CELL  # move the DSP down by 1 cell
.endm
```

Our new `tib` variable looks like this:

```
defcode "tib", 0x0388ae44, TIB, EMIT
    PUSHVAR TIB         # store TIB variable value in TOS
    NEXT
```

Not bad! Now we can do the same for the other variables.

#### Closing Thoughts

It was nice to restore the macro for `POP`. That completes the review of primitive words and variables. Next I'll be able to tackle `COLON` and `SEMI`.. and whatever else is missing haha.