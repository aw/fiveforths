# November 22, 2022

1. [Reverting code](#reverting-code)
2. [Log 7](#log-7)
3. [Removing primitives](#removing-primitives)
4. [Reviewing primitives pt2](#reviewing-primitives-pt2)
5. [Closing Thoughts](#closing-thoughts)

## Reverting code

It seems I may have made a few mistakes in my previous session. I'll need to revert some code.

### Log 7

I knew I had read about the `TOS` register somewhere else.. it was in [Brad Rodriguez: Moving Forth pt.1](http://www.bradrodriguez.com/papers/moving1.htm), where he mentions the major downside of a `TOS` and `SOS`:

> a push becomes a push followed by a move

I'll revert to only using a `TOS` (as per my original design) and once more review my primitives.

#### Removing primitives

The review will start from the top. I'll remove my new `DUALPOP` macro. I'll also remove `POP` and `PUSH` because I don't think they'll be needed anymore. In the future if I notice some repetitive code then I'll convert them to macros, but for now I think we can live without them. I'll also remove the `RCALL` macro because I honestly have no idea what it's for.

#### Reviewing primitives pt2

We'll start with `STORE`, since `FETCH` only uses the `TOS` and is confirmed working as expected:

```
# ! ( x addr -- )       Store x at addr
defcode "!", 0x0102b5c6, STORE, FETCH
    lw t0, 0(sp)        # load the DSP value (x) into temporary
    sw t0, 0(s3)        # store temporary into address stored in TOS (addr)
    lw s3, CELL(sp)     # load second value in DSP to TOS
    addi sp, sp, 2*CELL # move DSP up by 2 cells
    NEXT
```

It was changed to load the value of `x` at the top of the `DSP`, into a temporary register `t0`. It then stores that value into the memory address `addr` pointed by the value stored in the `TOS` (`s3`). Finally, it moves the next value in the `DSP` over to the `TOS` and adjusts the stack size to reflect the two values that were removed.

Next, for the `DSPFETCH` primitive, we want to place the current address of the stack pointer `DSP` into the `TOS`. Then we'll copy the `DSP` into the `TOS`, and move the stack pointer down by 1 cell:

```
# sp@ ( -- addr )       Get current data stack pointer
defcode "sp@", 0x0388aac8, DSPFETCH, STORE
    sw s3, -CELL(sp)    # store the value in the TOS to the top of the DSP
    mv s3, sp           # copy DSP to TOS
    addi sp, sp, -CELL  # move the DSP down by 1 cell to make room for the TOS
    NEXT
```

I'm assuming we want to store the _current_ stack pointer address in the `TOS` _before_ moving the pointer to a new address.. so technically if we run this twice in a row we'll get consecutive addresses (off by 4).

We do something similar for the `RSPFETCH` primitive except we're copying `RSP` into `TOS`:

```
# rp@ ( -- addr )       Get current return stack pointer
defcode "rp@", 0x0388a687, RSPFETCH, DSPFETCH
    sw s3, -CELL(sp)    # store the value in the TOS to the top of the DSP
    mv s3, s2           # copy RSP to TOS
    addi sp, sp, -CELL  # move the DSP down by 1 cell to make room for the TOS
    NEXT
```

I'm already noticing a pattern between `sp@` and `rp@`, so let's see if I can reorganize those into a macro which moves the `TOS` value into the `DSP` and the moves the stack pointer down by 1 cell. I can probably call it, oh.. let's see... how about `PUSH`:

```
# push register to top of stack
.macro PUSH reg
    sw s3, -CELL(sp)    # store the value in the TOS to the top of the DSP
    mv s3, \reg         # copy reg to TOS
    addi sp, sp, -CELL  # move the DSP down by 1 cell to make room for the TOS
.endm
```

This simplifies our `DSPFETCH` and `RSPFETCH` primitives:

```
defcode "sp@", 0x0388aac8, DSPFETCH, STORE
    PUSH sp
    NEXT

defcode "rp@", 0x0388a687, RSPFETCH, DSPFETCH
    PUSH s2
    NEXT
```

Haha. I had a feeling I would end up needing `PUSH` once more. Of course, the above code is almost identical to the _sectorforth_ implementation, so I'll assuming i'm on the right track.

#### Closing Thoughts

There's still a few more primitives to review and adjust, but I'll take a break for now and let these changes sink in before continuing in the next sesssion.
