# January 07

1. [Log 36](#log-36)
2. [From DTC to ITC](#from-dtc-to-itc)
3. [Cleaning up lookup](#cleaning-up-lookup)
4. [Closing thoughts](#closing-thoughts)

### Log 36

In this session I fix a few bugs which made me switch threading mode.

### From DTC to ITC

In _devlog 29_ I mentioned my goal of implementing this **Forth** as a _Direct Threaded Code_ (DTC) Forth, but I ended up banging my head on the wall trying to actually make it work _correctly_.

It works but it doesn't work. The main issue was with executing compiled words which included other compiled words. The address loaded in the `W` register was the address of the word, not the address pointed to by the word (`docol`). There is likely a way to fix it, but I got annoyed with the idea that _compiled_ words need to be executed differently from _primitive_ words.

For that reason, I decided to model my Forth on the classic _Indirect Threaded Code_ (ITC) approach found in many implementations such as _jonesforth_ and _derzforth_.

To make these changes, we first need to modify the `NEXT` macro to add another level of indirection:

```
-    jr a0               # jump to the address in W
+    lw t0, 0(a0)        # load address from W into temporary
+    jr t0               # jump to the address in temporary
```

Next, I added another level of indirection for jumping to docol:

```
-    la a2, docol        # load the codeword address into Y working register
+    la a2, .addr        # load the codeword address into Y working register
```

And the `.addr` is defined here as a jump to `docol`:

```
+.addr:
+    j docol             # indirect jump to interpreter after executing a word
```

Finally, when executing a word, we want a double-indirection to the outer interpreter similar to `NEXT`:

```
-.loop: .word process_token  # indirect jump to interpreter after executing a word
+.loop: .word .dloop         # double indirect jump to interpreter
+.dloop: .word process_token # indirect jump to interpreter after executing a word
```

One more change I made was to the `defcode` macro. I wanted to have specific global labels for each part (link, hash, code), and a global label for the _body_ which is where the Assembly code is located. This makes everything much more clear when debugging and it's easier to trace. Here's the full macro after modifications:

```
.macro defcode name, hash, label, link
    .section .rodata
    .balign CELL        # align to CELL bytes boundary
    .globl word_\label
  word_\label :
    .4byte word_\link   # 32-bit pointer to codeword of link
    .globl hash_\label
  hash_\label :
    .4byte \hash        # 32-bit hash of this word
    .globl code_\label
  code_\label :
    .4byte body_\label  # 32-bit pointer to codeword of label
    .globl body_\label
  body_\label :         # assembly code below
.endm
```

Now we can test some Forth code in the terminal. First we'll define `dup`, then we'll define `invert`, then we'll call `invert` on the stack value `-66`, and emit that to the terminal. It should print an `A` which is `0x00000041` or decimal `65` (`nand` of `-66` and `-66`):

```
: dup sp@ @ ;<Enter>   ok
: invert dup nand ;<Enter>   ok
-66 invert<Enter>   ok
emit<Enter> A   ok
```

**Yessss!!!**

### Cleaning up lookup

The `lookup` function was not cleaning up after itself when an error was found. This was not an issue when _executing_ words, only when _compiling_ because it would essentially leave a word half-compiled in memory.

I think the first change is to make a copy of `LATEST` once we enter the function. This is the value we want to restore if there's an error, but we only want to do it once:

```
 lookup:
-    beqz a1, error              # error if the address is 0 (end of the dictionary)
+    mv t2, a1                   # copy the address of LATEST
```

Next, we want to move our guard to the loop part, which will happen on every word that's looked up:

```
+lookup_loop:
+    beqz a1, lookup_error       # error if the address is 0 (end of the dictionary)
```

In `lookup_next`, we want to jump to the loop instead, so let's change that:

```
-    j lookup
+    j lookup_loop
```

Then we can begin to define our custom lookup error handler:

```
lookup_error:
    # check the STATE
    li t0, STATE                # load the address of the STATE variable into temporary
    lw t0, 0(t0)                # load the current state into a temporary
    beqz t0, error              # if in execute mode (STATE = 0), jump to error handler to reset
```

First want want to check the `STATE` of the interpreter. If we're in _execute_ mode then it's safe to jump to the `error` function which will handle resetting things (without touching `HERE` or `LATEST`).

Otherwise, if we're in _compile_ mode, we want to store our previously saved `LATEST` value into `HERE`. This rolls back the memory address of `HERE` as if we didn't even define a word:

```
    # update HERE since we're in compile mode
    li t0, HERE                 # load HERE variable into temporary
    sw t2, 0(t0)                # store the address of LATEST back into HERE
```

Next, we want to update `LATEST` so it points back to the previous word that was defined before the current one. That address is actually still there in memory, at the location pointed to by `HERE` (the `t2` register from earlier):

```
    # update LATEST since we're in compile mode
    li t0, LATEST               # load LATEST variable into temporary
    lw t1, 0(t2)                # load LATEST variable value into temporary
    sw t1, 0(t0)                # store LATEST word into LATEST variable
```

Once that's done, we can jump to the `error` function to handle resetting other things:

```
    j error                     # jump to error handler
```

### Closing thoughts

Alright, now _everything_ actually works!! (I hope)

Now there's only one small bug remaining, which is related to hitting backspace in the terminal. It's probably a small issue, but I'll get to that eventually. In the next session, I'll publish the `README`, and work on the documentation, examples, optimizations, and code cleanup.
