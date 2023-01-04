# January 04, 2023

1. [Log 31](#log-31)
2. [Reviewing token](#reviewing-token)
3. [Interpreting words](#interpreting-words)
4. [Closing thoughts](#closing-thoughts)

### Log 31

In this session I'm going to review the `token` function from `src/05-internal-functions.s` before reviewing the interpreter in file `src/09-interpreter.s`.

### Reviewing token

In my `token` function, I read characters backward from `TOIN` to the start of the word. This makes no sense because it'll then be impossible to read the _next_ word. I'll need to make some adjustments for the `TOIN` variable location, but let's start by fixing `token`.

First, since we're not comparing `TOIN` with the `TIB` address anymore, we can remove that guard:

```
-    blt a1, a0, token_done      # compare the address of TOIN with the address of TIB
```

Next, we want to increment `TOIN` by 1 for each character found, instead of decrementing:

```
-    addi a1, a1, -1             # move TOIN pointer down
+    addi a0, a0, 1              # move buffer pointer up
+    beqz t0, token_zero         # compare char with 0
```

I moved the buffer address to `W` instead of `X`. Here I also added a new branch address called `token_zero`. The `TIB` will always be filled with zeroes first, so we want to keep scanning the `TIB` until we find a zero. That's a character which can't be input via the UART/serial terminal, and doesn't belong in the terminal input buffer (except when we initialize it).

Next, when we find a `space` character, we want to ignore it because we know we're done scanning our token:

```
+    addi a0, a0, -1             # move buffer pointer down to ignore the space character
+    sub a0, a0, t2              # store the start address in W
+    j token_done
```

We'll use that opportunity to store the new `TOIN` address in the `W` (`a0`) working register.

Our `token_zero` label looks like this:

```
+token_zero:
+    addi a0, a0, -1             # move buffer pointer down to ignore the 0
```

It does this because we also want to ignore the zero if we find it (by moving `TOIN` back by 1). This will automatically fall into `token_done` afterwards, whose only job is to store the size of the token in the `X` (`a1`) working register, and then return from the function:

```
token_done:
    mv a1, t2                   # store the size in X
    ret
```

That's all for adjusting the `token` function. Now we can jump back to the interpreter and fix that.

### Interpreting words

The first change I want to make is ensure our `.loop` function jumps to `process_token` instead of `ok`. We obviously don't want to print `ok` after scanning only _one_ word in the buffer:

```
-.loop: .word ok             # indirect jump to interpreter after executing a word
+.loop: .word process_token  # indirect jump to interpreter after executing a word
```

Next, in our `interpreter_tib` function, we don't actually want to start processing the token just yet, first we need to replace the _newline_ with a _space_, so let's jump to a different label:

```
-    beq a0, t0, process_token                   # process the token if it matches
+    beq a0, t0, replace_newline                 # process the token if it matches
```

Then, where we convert the _newline_ to a _space_, we'll change the label name as well:

```
-process_token:
+replace_newline:
```

Now things start to make a bit more sense, let's re-add the `process_token` label a bit lower, where we actually "process" the "token" right before calling the `token` function. This is where we'll loop to after executing a word:

```
+process_token:
     # process the token
-    mv a0, t2               # load the TIB address in the W working register
+    li t3, TOIN             # load TOIN variable into unused temporary register
+    lw a0, 0(t3)            # load TOIN address value into temporary
     call token              # read the token
```

We made a few changes here, the first was removing the naive approach of just copying the `TIB` address into `W`.

This can probably be optimized by renaming some registers, but for now we want to reload `TOIN` into a temporary, and then load the `TOIN` address into `W`, before calling `token`. This ensures it'll get the correct buffer address to start with.

Once the call returns, we won't need to reload `TOIN` because we'll already have it in `W` (`a0`), as well as the token's size in `X` (`a1`). We can just add them together to get the new `TOIN` address:

```
-    lw t0, 0(t3)            # load TOIN address value into temporary
-    add t0, t0, a1          # add the size of the token to TOIN
+    add t0, a0, a1          # add the size of the token to TOIN
     sw t0, 0(t3)            # move TOIN to process the next word in the TIB

     # bounds checks on token size
     beqz a1, ok             # ok if token size is 0
```

This seems to work well. In the event where our token size is 0, because the last character was a space or a 0, then we're done processing tokens and the bounds check will jump to `ok`, which re-initializes the `TIB` before looping back to the interpreter. Note the stack is _not_ reset, so our `sp` stack pointer will remain and the words we entered in the terminal will have executed and their results will be stored in (or removed from) the stack (assuming they actually modify the stack).

Example:

```
(gdb) i r sp
sp             0x20004ffc	0x20004ffc
(gdb) x/xw 0x20004ffc
0x20004ffc:	0x00000000
(gdb) c
Continuing.

Breakpoint 1, interpreter_start () at src/09-interpreter.s:11
```

Now in the terminal I type `latest<Enter`:

```
latest ok
```

And back in `GDB`:

```
(gdb) i r sp
sp             0x20004ff8	0x20004ff8
(gdb) x/xw 0x20004ff8
0x20004ff8:	0x080004f8
(gdb) x/xw 0x080004f8
0x80004f8 <word_SEMI>:	0x080004ec
```

Perfect! There's the address of the latest word we defined: `SEMI`.

### Closing thoughts

I'm happy I can now execute multiple words from the terminal. The next step is to try and _compile_ words. I'll also need to ensure we call `number` so we can store numbers in the stack. I'll try to focus on those two things in the next session, and see if I can find any bugs in the current implementation. Almost done!
