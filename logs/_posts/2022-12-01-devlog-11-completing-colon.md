# December 1, 2022

1. [Log 11](#log-11)
2. [Completing COLON](#completing-colon)
3. [Closing thoughts](#closing-thoughts)

## Log 11

I think this session will be short since I only plan to "complete" the `COLON` primitive.

### Completing COLON

OK so I wrote quite a few lines of code to finish this definition, without logging what I was doing. So I'll start by showing what a word definition should look like in memory:


```
+----------+----------+----------+
|   LINK   |   HASH   | CODEWORD |
+----------+----------+----------+
 32-bit     32-bit     32-bit
```

It's similar to how _jonesforth_ does it, except we don't need to store the length of the word.

I realized later that we need to set the `HIDDEN` flag inside the hash (in the second bit starting from the MSB), to ensure the it can't be found during a lookup in compilation mode:

```
    # set the hidden flag in the hash
    li t0, F_HIDDEN      # load hidden flag into temporary
    or a0, a0, t0        # hide the word
```

Next, I want to load some variables into temporary registers, because I'll use them later:

```
    # copy the memory address of some variables to temporary registers
    li t0, HERE
    li t1, LATEST
    la t2, enter        # load the codeword address into temporary # FIXME: enter or docol?
```

Notice I put a `# FIXME` for loading the address of the `enter` label. I did that because _derzforth_ uses it as the codeword, but I have a feeling I may be mistaken in copying that implementation. _sectorforth_ and _jonesforth_ point to _docol_, so I need to read more about this later.

Next I want to load the actual values pointed by the `HERE` and `LATEST` variables:

```
    # load and update memory addresses from variables
    lw t3, 0(t0)        # load the new start address of the current word into temporary (HERE)
    lw t4, 0(t1)        # load the address of the previous word into temporary (LATEST)
```

They're stored in different temporary registers because we'll need to write to `t0` and `t1` later. This should save a couple instructions.

From here it becomes quite simple, we're first going to update the `LATEST` variable to point to the value pointed by `HERE`. Essentially we want `LATEST` to point to this new word's start address.

```
    # update LATEST variable
    sw t3, 0(t1)        # store the current value of HERE into the LATEST variable
```

Then we're going to build the header (LINK, HASH, CODEWORD) by storing it in memory at the `HERE` address:

```
    # build the header in memory
    sw t4, 0(t3)        # store the address of the previous word
    sw a0, 4(t3)        # store the hash
    sw t2, 8(t3)        # store the codeword address
```

The LINK mentioned above is the address of the previous word, aka `LATEST`.

The next step is to update the `HERE` variable, similarly to what we did with `LATEST` above, except we're now going to point `HERE` to the _end_ of the word:

```
    # update HERE variable
    addi t3, t3, 12     # move the HERE pointer to the end of the word
    sw t3, 0(t0)        # store the new address of HERE into the HERE variable
```

I'm using a 12-byte offset because we stored `3 * 32` (`96 bits / 12 bytes`) of data in memory.

The final step in our `COLON` definition is to update the `STATE` variable. We want to set it to `1` so the interpreter knows we're now in compilation mode:

```
    # update STATE variable
    li t0, STATE        # load the address of the STATE variable into temporary
    li t1, 1            # set the STATE variable to compile mode (1 = compile)
    sw t1, 0(t0)        # store the current state back into the STATE variable
    NEXT
```

I think (hope?) that completes the `COLON` definition.

### Closing thoughts

The good news is the code still compiles, and I can run it just fine in the _Ripes_ simulator. Inspecting the memory addresses and registers confirms that the code works as expected, and the correct values are stored in the correct locations, but I still need to figure out the whole _codeword_ thing (enter/docol?).

In the next session, I'm hoping to fully understand the roles of `docol` and `enter`, and maybe move onto the next missing primitive: `SEMI` (`;`).