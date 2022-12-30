# December 30, 2022

1. [Log 27](#log-27)
2. [Lookup](#lookup)
3. [Execute or compile](#execute-or-compile)
4. [Closing thoughts](#closing-thoughts)

### Log 27

In this session I'm focused on performing hashed word lookups over the dictionary (linked list).

### Lookup

Before performing a lookup, I forgot one important step after obtaining the _token_: moving `TOIN`. This is important because it helps the interpreter search for the next word when it loops. If we don't move `TOIN`, we'll keep searching from the start of the `TIB` (or in this case, from the same `TOIN` address). Let's fix that:

```
    # move TOIN
    lw t0, 0(t3)            # load TOIN address value into temporary
    add t0, t0, a1          # add the size of the token to TOIN
    sw t0, 0(t3)            # move TOIN to process the next word in the TIB
```

Now in `process_token`, after hashing the word with the `djb2_hash` function, we'll need to load the `LATEST` word into a register. The `lookup` function will start searching from there, and as it loops it'll jump to the next word and so-on, until it finds it or reaches the end:

```
    li a1, LATEST           # load LATEST variable into temporary
    lw a1, 0(a1)            # load LATEST value into temporary
    call lookup             # lookup the hash in the dictionary
```

OK so let's define `lookup`. It's mostly inspired by the _derzforth_ implementation. Here are the parameters:

```
# search for a hash in the dictionary
# arguments: a0 = hash of the word, a1 = address of the LATEST word
# returns: a0 = hash of the word, a1 = address of the word if found
```

The first parameter, `a0` doesn't get modified during the lookup, but we'll return it intact in case we want to use it later. The `a1` parameter contains the address of the `LATEST` word and will return with the address of the found word (if found). If the word isn't found (i.e: if we reach the end of the dictionary) then it's an error and we'll reset everything:

```
lookup:
    beqz a1, error              # error if the address is 0 (end of the dictionary)
```

The above works because our first primitive is linked to the word `NULL` which has the value `0`, see here:

```

.equ word_NULL, 0

# @ ( addr -- x )       Fetch memory at addr
defcode "@", 0x0102b5e5, FETCH, NULL
```

Next, if we recall _devlog 20_, we need 3 CELLs for a word (link, `hash`, codeword). So if we want to get the hash of the word, we need to load it from offset `+4`:

```
    lw t0, 4(a1)                # load the hash of the word from the X working register
```

Afterwards, we want to skip the word if it's `HIDDEN`. This is important for skipping the word we're currently defining, as well as other words which should be skipped:

```
    # check if the word is hidden
    li t1, F_HIDDEN            # load the HIDDEN flag into temporary
    and t1, t0, t1             # read the hidden flag bit
    bnez t1, lookup_next       # skip the word if it's hidden
```

Here we load the `HIDDEN` flag mask into a temporary, and perform a logical `AND` which will help use determine if the word is hidden or not. If it's hidden, we'll skip it and load the previous word linked in the dictionary before looping back to the `lookup` function:

```
lookup_next:
    lw a1, 0(a1)               # follow link to next word in dict
    j lookup
```

Notice we're loading from offset `0` this time, which is the `link` (side note: offset `+8` would be the `codeword`, which we'll use later).

Assuming our word was not hidden, we'll then remove the top 3 bits using the inverted 3-bit flags mask. This way we'll only compare a word based on the remaining length + hash (5 + 24 bits):

```
    # remove the 3-bit flags using a mask
    li t1, ~FLAGS_MASK         # load the inverted 3-bit flags mask into temporary
    and t0, t0, t1             # ignore flags when comparing the hashes
    beq t0, a0, lookup_done    # done if the hashes match
```

And if the hashes match, then we can return from the function:

```
lookup_done:
    ret
```

Otherwise, it'll continue to `lookup_next`. That's all for our `lookup` function!

### Execute or compile

The final step is to decide if we want to execute the word, or compile it. The way _sectorforth_ handles that is to load the `IMMEDIATE` flag from the word, and the `STATE` variable, and then perform a logical `OR`, then decrement that result by 1. If the final result is `0` then we _compile_, otherwise we _execute_. Here's the truth table borrowed from _sectorforth_:

```
        ; IMMEDIATE     STATE         OR   ACTION
        ;   0000000   0000000   00000000   Interpret
        ;   0000000   0000001   00000001   Compile
        ;   1000000   0000000   10000000   Interpret
        ;   1000000   0000001   10000001   Interpret
```

So let's return to our `process_token` function, right after we `call lookup`, we'll check if the word has the `IMMEDIATE` flag set:

```
    # check if the word is immediate
    lw t0, 4(a1)            # load the hash of the found word into temporary
    li t1, F_IMMEDIATE      # load the IMMEDIATE flag into temporary
    and t0, t0, t1          # read the status of the immediate flag bit
```

Here we loaded the hash of the found word (again, at offset `+4`), and performed a logical `AND` with the `IMMEDIATE` flag mask.

Next we'll load the `STATE` variable:

```
    # load the STATE variable value
    li t1, STATE            # load the address of the STATE variable into temporary
    lw t1, 0(t1)            # load the current state into a temporary
```

And finally we make our decision:

```
    # decide if we want to execute or compile the word
    or t0, t0, t1           # logical OR the immediate flag and state
    addi t0, t0, -1         # decrement the result by 1
    beqz t0, compile        # compile the word if the result is 0
```

### Closing thoughts

I think the `NEXT` macro might be broken, since I haven't reviewed it at all since it was first written in 2021. In the next session I'll start with reviewing the `NEXT` macro, and then focus on _compiling_ and _executing_ code. I'll also write a short test routine to test the `lookup` function.
