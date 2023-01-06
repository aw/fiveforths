# January 06

1. [Log 35](#log-35)
2. [Compiling words pt2](#compiling-words-pt2)
3. [Done](#done)
4. [Closing thoughts](#closing-thoughts)

### Log 35

In this session, I actually plan on fixing compilation and getting to **DONE!**

### Compiling words pt2

I decided to step through the execution of a compiled word: `dup` using `GDB`.

The first problem I noticed was the indirect jump to `docol` in `COLON` was not working. In fact, it doesn't need any indirection since we're actually jumping straight to it. Let's fix that:

```
-    la a2, .addr        # load the codeword address into Y working register
+    la a2, docol        # load the codeword address into Y working register
```

And then we can get rid of `.addr`:

```
-.addr: .word docol      # indirect jump to docol from a colon definition
```

Next issue was in `docol`, we don't expect the code field address in `Y`, that makes no sense. We expect it in `W`, like in every other **Forth**:

```
-    addi s1, a2, CELL   # skip code field in Y by adding a CELL, store it in IP
+    addi s1, a0, CELL   # skip code field in W by adding 1 CELL, store it in IP
```

Finally, the macro `defcode` for defining a word was completely wacky. It had a mix of code from `sectorforth` and `jonesforth` and some weirdness added by me because I store a _hash_ of the word instead of the _length+name_. In any case, I had to rewrite the entire macro and I ended up with this:

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
    .4byte code_\label  # 32-bit pointer to codeword of label
    .globl code_\label
  code_\label :         # assembly code below
.endm
```

This is a bit better. The `codefield` now points to `hash_\label+4`, which will move directly to the `code_\label`. I think that adds an extra cycle and would rather have the code jump to `code_\label`, but when I do that the interpreter crashes... I guess I'll need to fix that another time.

For the time being, let's test out our `dup` once more in the terminal:

```
: dup sp@ @ ;<Enter>  ok
```

And let's inspect the 6 values in `GDB`:

```
(gdb) x/6xw 0x20000000
0x20000000:	0x080004d0	0x03886bce	0x080004c0	0x080002b4
0x20000010:	0x0800027c	0x08000344
```

The first 2 are the link to the previous word and the hash.. unchanged since the previous _devlog_:

```
(gdb) x/xw 0x080004c0
0x80004c0 <docol>:	0xfe992e23
(gdb) x/xw 0x080002b4
0x80002b4 <hash_DSPFETCH+4>:	0x080002b8
(gdb) x/xw 0x0800027c
0x800027c <hash_FETCH+4>:	0x08000280
(gdb) x/xw 0x08000344
0x8000344 <code_EXIT>:	0x00092483
```

**Perfect!!** (_almost_).

If I gather up the courage to fix the issue I mentioned above, it would look like `docol, code_DSPFETCH, code_FETCH, code_EXIT`. Now let's try running `dup` in the terminal:

```
123 dup<Enter>  ok
```

This should leave `123` as the first two entries in the stack. Let's check the stack with `GDB`:

```
(gdb) i r sp
sp             0x20004ff8 0x20004ff8
(gdb) x/dw 0x20004ff8
0x20004ff8: 123
(gdb) x/dw 0x20004ff8+4
0x20004ffc: 123
```

**Great!**

Now we have confirmation that we can _execute_ AND _compile_ words!!

### Done

And there we have it, my first fully functional **Forth** (and programming language written from scratch).

### Closing thoughts

This is super exciting! There are still a few minor bugs to fix and features to add, but I'll focus on bugs/optimizations first, code cleanup and comments, and maybe getting some examples and a `README` up for others to use this.
