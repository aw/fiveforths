# January 19

1. [Log 38](#log-38)
2. [Release v03](#release-v03)
3. [Bug fixes](#bug-fixes)
4. [Enhancements](#enhancements)
5. [Closing thoughts](#closing-thoughts)

### Log 38

In this session I'll discuss the bugs I fixed, some enhancements, and documentation for _FiveForths_.

### Release v03

In [release v0.3](https://github.com/aw/fiveforths/releases/tag/v0.3) I made quite a few changes, most importantly is regarding documentation, so let's start there.

A new sub-directory was created, called [docs/](https://github.com/aw/fiveforths/tree/master/docs) which contains, you guessed it, documentation! It's using a system called [Diátaxis](https://diataxis.fr/) which was previously the [Divio](https://documentation.divio.com/) docs, which I believe were created by [Daniele Procida](https://diataxis.fr/contact/). I've used it in [previous](https://github.com/aw/picolisp-posixmq/tree/master/docs) [projects](https://github.com/aw/hw-micro3d/tree/master/docs) over the last few years and have grown quite fond of it.

The major goal of those documents is to allow people to learn about _FiveForths_, to write their own _Forth_ code and maybe even contribute some _Assembly_ code. I'll continue adding to it as needed, but please feel free to contribute any changes which may help (even typos in the docs).

The next important changes were some bug fixes. I opened 4 issues on GitHub and [1 pull request](https://github.com/aw/fiveforths/pull/15/files) prior to rebase-merging into the _master_ branch.

### Bug fixes

The `STORE` bug in [issue 14](https://github.com/aw/fiveforths/issues/14) was a real simple one. The `!` (`STORE`) primitive should store `x` in `addr`. I'm not sure how I overlooked it, but I somehow managed to reverse the order and found myself storing `addr` in `x`. I swear I tested it, so I reviewed [devlog 32](https://fiveforths.a1w.ca/devlog-32-fixing-bugs#fixing-primitives) and I realize my mistake. The code:

```
here @ latest @ !<Enter>
```

It had the arguments backwards! That command would normally try to store `HERE` into `LATEST` (in a working _Forth_), but since it was reversed in my code (and in the example), it actually **worked**. It ended up storing `LATEST` in `HERE` and worked perfectly. Oops!

Here's the fixed code in the `STORE` primitive:

```
-    lw t0, 0(sp)        # load the DSP value (x) into temporary
-    lw t1, CELL(sp)     # load the DSP value (addr) into temporary
+    lw t1, 0(sp)        # load the DSP value (addr) into temporary
+    lw t0, CELL(sp)     # load the DSP value (x) into temporary
```

The `TOIN` bug in [issue 13](https://github.com/aw/fiveforths/issues/13) was a bit more complex. In fact it didn't affect the way _FiveForths_ worked, as it only affected the result from using `>in` in _Forth_ code. With `>in` it should actually store the buffer position in the `TIB`, but in my case I was storing a memory address in `TOIN`, so using `>in` correctly would require one to subtract the value from `tib` in order to obtain the _real_ `>in`.

I fixed this without changing too much code. The main thing I realized was that my usage of `TOIN` within the assembly code was fine. I just needed to make sure the value it stored and loaded to/from memory was not an address.

The first change was to initialize `TOIN` to zero rather than a memory address:

```
-    sw t0, 0(t1)        # initialize TOIN variable to contain TIB start address
+    sw zero, 0(t1)      # initialize TOIN variable to contain zero
```

Next, when _loading_ `TOIN`, we need to add the address of `TIB` so the rest of the code can function as usual. Let's have a look at the interpreter:

```
-    lw a1, 0(t3)                                # load TOIN address value into X working register
+    lw a1, 0(t3)                                # load TOIN value into X working register
+    add a1, a1, t2                              # add TIB to TOIN to get the start address of TOIN
```

Then, when _storing_ `TOIN`, we need to subtract the address of `TIB`:

```
+    li t2, TIB              # load TIB memory address
     add t0, a0, a1          # add the size of the token to TOIN
+    sub t0, t0, t2          # subtract the address of TOIN from TIB to get the new size of TOIN
     sw t0, 0(t3)            # move TOIN to process the next word in the TIB
```

See? Here we load `TIB` into a temporary because it wasn't available elsewhere, so we add the size of the token, then we subtract the value of `TIB` to obtain the real size of `TOIN` before storing it back into the variable. That's a mouthful but it works and was super easy to implement and validate. I made the same change in `COLON` (which also manipulates `TOIN`) and we're good to go.

### Enhancements

Two of the enhancements I focused on were to ensure the user dictionary and data/return stacks don't overflow (or underflow). We want to make sure our code stays within the memory boundaries assigned to them.

Another enhancement was regarding error handling, and I'm quite happy about this one. In _sectorforth_ there's practically no error handling and many _Forths_ are somewhat cryptic about what's going on. We want to know why something went wrong, so let's add some proper error messages.

I noticed the code for `error, ok, reboot` was quite similar, and I wanted to add other types of messages, so the first step was to create a new macro to print error messages:

```
# print a message
.macro print_error name, size, jump
    .balign CELL
  err_\name :
    la a1, msg_\name    # load string message
    addi a2, a1, \size  # load string length
    call uart_print     # call uart print function
    j \jump             # jump when print returns
.endm
```

It's fairly simple, all it does is generate a label (ex: `err_error`), code for loading a string message (ex: under the label `msg_error`), printing the message, and then jumping to a label specified as an argument.

It would be used like this:

```
print_error error, 4, reset
msg_error: .ascii "  ?\n"
```

When there's a jump to the label `err_error`, it will load the ASCII error message stored in `msg_error`, add its size (`4`), print it to the UART, then jump to the `reset` label.

I defined similar code for other messages as well:

```
print_error error, 4, reset
print_error ok, 6, tib_init
print_error reboot, 16, _start
print_error tib, 14, reset
print_error mem, 16, reset
print_error token, 14, reset
print_error underflow, 20, reset
print_error overflow, 20, reset

msg_error: .ascii "  ?\n"
msg_ok: .ascii "   ok\n"
msg_reboot: .ascii "   ok rebooting\n"
msg_tib: .ascii "   ? tib full\n"
msg_mem: .ascii "  ? memory full\n"
msg_token: .ascii "  ? big token\n"
msg_underflow: .ascii "  ? stack underflow\n"
msg_overflow: .ascii "   ? stack overflow\n"
```

I think that's slightly more useful than just `?` and `ok` haha.

The new messages such as `msg_mem` and `msg_overflow` are for the code which handles the bounds checks on memory and stacks.

I won't go into full detail of the changes required to perform bounds checks, but I will highlight a few things.

First, I defined yet another new macro, this one is for handling errors where the values stored in memory are incomplete. For example during a word lookup, if we're in _compile_ mode, we absolutely must not leave the memory in a half-baked state. That means restoring `HERE` and `LATEST`. The same rule applies when `;` (`EXIT`) is encountered, if there isn't enough memory to store that word, then the entire word's definition must be rolled back. Here's the new macro to handle that:

```
# restore HERE and LATEST variables
.macro restorevars reg
    # update HERE
    li t0, HERE         # load HERE variable into temporary
    sw \reg, 0(t0)      # store the address of LATEST back into HERE

    # update LATEST
    li t0, LATEST       # load LATEST variable into temporary
    lw t1, 0(\reg)      # load LATEST variable value into temporary
    sw t1, 0(t0)        # store LATEST word into LATEST variable
.endm
```

It's quite straightforward, it simply stores the provided register value of `LATEST` into `HERE`, and then it updates `LATEST` to contain the previously stored word in `LATEST`. It sounds weird to update `LATEST` with `LATEST` but actually it's not, it's just storing the pointer value of `LATEST` into `LATEST`, which is a different address. Essentially it ends up restoring the old `LATEST` and `HERE` variables to the previous state.

Another important change regarding memory bounds checking... after restoring the variables and jumping to the `reset` handler, I absolutely want to **zerofill** the memory. In fact, I want to do this on every reset (physical or virtual). I don't like the idea of leaving old values in memory after a soft reset, so some code was added to fully zero out the RAM. Of course I was careful to only reset from the `HERE` address, since we don't want to lose our correctly defined words haha (if yes, then do a `reboot` to start from scratch):

```
# reset the RAM from the last defined word
ram_init:
    li t0, HERE         # load HERE memory address
    lw t0, 0(t0)        # load HERE value
    li t1, PAD          # load PAD variable
ram_zerofill:
    # initialize the memory cells
    beq t0, t1,ram_done # loop until counter (HERE) == PAD
    sw zero, 0(t0)      # zero-fill the memory address
    addi t0, t0, CELL   # increment counter by 1 CELL
    j ram_zerofill      # repeat
ram_done:
    # continue to tib_init
```

I guess this code is extremely similar to `tib_init`, where it just writes 4 bytes (zeroes) to every memory address from `HERE` to `PAD` (but it doesn't touch `PAD`). I tested on the _Longan Nano_'s 20 KBytes and it's pretty quick even running at 8 MHz haha. I can't imagine this would be problematic even on a larger microcontroller, but we'll see.. the `reset` only occurs on error anyways (and first boot), so it won't affect code that's running fine and error-free.

Finally, for bounds checks on the stacks, I modified some macros and primitives with code similar to this in the `POPRSP` macro:

```
    li t0, RSP_TOP              # load address of top of RSP
    bge s2, t0, err_underflow   # jump to error handler if stack underflow
```

The above code performs a stack _underflow_ check on the return stack. All it does is jump to the `err_underflow` error handler if the value of the `RSP` pointer (`s2`) is equal or greater than the value of the `RSP_TOP` constant. Both are memory addresses, and if they're lined up then it should not be possible to perform a `POPRSP`. That's called an _underflow_.

For the _overflow_ check we can look at the `PUSH` macro:

```
    li t0, RSP_TOP+CELL         # load address of bottom of stack + 1 CELL
    blt sp, t0, err_overflow    # jump to error handler if stack overflow
```

This is similar to `POPRSP` except it's using the `RSP_TOP` constant + 1 CELL, which is essentially the _last_ available memory cell in the data stack. That value is fine, but anything below it is not. That's why we're using the `blt` (branch if less than) RISC-V instruction. If there were a `blte` instruction (branch if less than or equal) then we could write this instead:

```
    li t0, RSP_TOP
```

There might be a simpler way, but I'll leave that for the optimization stage (soon?).

So back to the over/under flow checks, anywhere the `sp` (`DSP`) or `s2` (`RSP`) pointers are manipulated, there will first be a check for a stack overflow or underflow condition. If yes then we'll print a friendly error message and jump to `reset`.

### Closing thoughts

I believe this release is quite stable now, but there's still a few more enhancements I want to make, such as adding the ability to _save_ or _load_ words either from the onboard SD card or from Flash memory. I still need to add the ability to write multi-line word definitions, and the ability to handle hex numbers. However I also want to avoid adding to much to the core _Forth_ (and avoid writing much more low-level RISC-V Assembly).

In the next session I'll focus on the above enhancements and maybe some code cleanup and optimization.
