# November 30, 2022

1. [Log 10](#log-10)
2. [Fixing bug](#fixing-bugs)
3. [Moving TOIN](#moving-toin)
4. [No indexes](#no-indexes)
5. [Testing my code](#testing-my-code)
6. [Creating the header](#creating-the-header)
7. [Closing thoughts](#closing-thoughts)

## Log 10

I want to start by jumping into the `COLON` primitive and adding the remaining instructions for it to work correctly, but first I need to fix some issues.

### Fixing bugs

In the last session, I made two mistakes in my code. The first was using `0x32` as the space character, which is not actually a _space_ but rather a _2_ (decimal 50). The hex value for _space_ is `0x20`, oops:

```
-    li t1, 0x32                 # initialize temporary to 'space' character
+    li t1, 0x20                 # initialize temporary to 'space' character
```

Next, I noticed that my previously defined `djb2_hash` functions starts hashing from the _start_ of the buffer, so the address stored in `W` (`a0`) needs to point to the right place. That was an easy fix, I just skip adding the size of the token haha:

```
-    add a0, a1, t2              # add the size of the token with the address of TOIN to W
```

### Moving TOIN

Now back to `COLON`, after the `call token` returns, we need to move the `TOIN` pointer to `W`, and we'll need to handle the error case where size 0 was returned before hashing the token.

```
    beqz a1, error      # error if token size was 0
    li t0, TOIN         # load TOIN into temporary
    sw a0, 0(t0)        # store new address into TOIN
    call djb2_hash      # hash the token
```

The `error` function doesn't do anything for the moment, I'll get to that another time. The `djb2_hash` function was already tested and confirmed working in [devlog 3](log-2022-11-17.md).

### No indexes

I thought about this some more, and decided that indexing words by hash/length would not be necessary at this stage. So I adjusted the code for that:

```
-.equ INDEXES, NOOP - (CELL * 64)        # 64 CELLS between NOOP and INDEXES
-.equ PAD, INDEXES - (CELL * 64)         # 64 CELLS between INDEXES and PAD
+.equ PAD, NOOP - (CELL * 64)            # 64 CELLS between NOOP and PAD
```

### Testing my code

I've been testing some hand-written functions manually in the [Venus RISC-V Simulator](), but I've simplified this by creating a `_testing` function which loads some dummy data into memory and registers, and then calls the piece of code I want to test:

```
_start:
    la sp, __stacktop
    j _testing
    ret

_testing:
    # preparing for creating a token
    li a0, TIB          # load TIB into W
    li t0, 0x20202020   # load a bunch of spaces
    sw t0, 4(a0)        # store 4 spaces in TIB
    li t0, 0x70756420   # load word 'dup' into temporary
    sw t0, 0(a0)        # store word in TIB address
    addi a1, a0, 7      # increment TIB by 7 (size of token + 4 spaces)
    li t0, TOIN         # load TOIN variable memory address into temporary
    sw a1, 0(t0)        # store new address location from temporary in TOIN variable
    j body_COLON
```

In the `_start` function, it will quickly jump to `_testing`, load some data into registers and store it in specific memory locations, before jumping to the `body_COLON` functions which is created in the macro call to `COLON`.

Now I can just load this into [Ripes](https://github.com/mortbopet/Ripes) or `gdb` and perform a quick run without copy/pasting code between my browser and text editor.

Of course, this is temporary and will not be published or included in the actual source code.

### Creating the header

Now I need to create the word's header, which starts at the memory address stored in `HERE`, and then add a pointer to the previous word's memory address from `LATEST`:

```
    li t0, HERE         # load the HERE variable into temporary
    lw t0, 0(t0)        # load the new start address of the current word into temporary
    li t1, LATEST       # load the LATEST variable into temporary
    lw t1, 0(t1)        # load the address of previous word's memory location into temporary
```

This loads the values stored in the `HERE` and `LATEST` variables into temporaries, which I'll use for creating the header:

```
    sw t1, 0(t0)        # store the address of the previous word
    sw a0, 4(t0)        # store the hash next
```

Now the address of the previous word will be stored in memory, and so will the hash. I think it will be necessary to _hide_ the word before compilation using the `F_HIDDEN` flag, but I'll save that for next session.

Finally, to test these additions, I extended my `_testing` function with the following:

```
    # prepare for storing
    li t0, HERE         # load HERE variable
    li t1, RAM_BASE     # load RAM_BASE variable
    sw t1, 0(t0)        # store RAM_BASE address in HERE variable
    li t0, LATEST       # load LATEST variable
    la t1, word_SEMI    # load address of the last word in Flash memory (;) for now
    sw t1, 0(t0)        # store latest address in LATEST variable
```

This initializes the `HERE` and `LATEST` variables to point to the start of the RAM and the start of the last primitive word defined `SEMI`.

### Closing thoughts

I feel this was a productive session, despite it taking much longer than expected to recover from my cold. There isn't much left for defining `COLON`, but I'll take a little break and get back to that next time.
