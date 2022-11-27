# November 27, 2022

1. [Log 9](#log-9)
2. [Minor adjustments](#minor-adjustments)
3. [First look at colon](#first-look-at-colon)
4. [Reading the first word](#reading-the-first-word)
5. [Closing thoughts](#closing-thoughts)

## Log 9

In this session I make some minor code adjustments, and then I'll make a first attempt at implementing the `COLON` primitive.

### Minor adjustments

In the `POP` macro, I was moving the stack pointer up, and then loading the previous stack pointer into a register from an address offset by -4. This was weird, so I changed it to load it into the register first from an offset of 0 before moving the stack pointer. It's easier to read this way:

```
 .macro POP reg
+    lw \reg, 0(sp)      # load DSP value to temporary
     addi sp, sp, CELL   # move the DSP up by 1 cell
-    lw \reg, -CELL(sp)  # load DSP value to temporary
 .endm
```

I was doing something equally weird in the `PUSH` macro, and adjusted that below:

```
 .macro PUSH reg
-    sw s3, -CELL(sp)    # store the value in the TOS to the top of the DSP
-    mv s3, \reg         # copy reg to TOS
-    addi sp, sp, -CELL  # move the DSP down by 1 cell to make room for the TOS
+    addi sp, sp, -CELL  # move the DSP down by 1 cell
+    sw s3, 0(sp)        # store the value in the TOS to the top of the DSP
+    addi s3, \reg, CELL # copy reg+CELL (old sp) to TOS
 .endm
```

You can see the order went from: `store -> copy -> move` to `move -> store -> copy`. Now there's no negative offset and it's much easier to follow.

### First look at colon

OK so now we're getting into a bit more meaty Assembly. The `COLON` primitive is what's used to define new Forth dictionary words. It should read the first word after the `:` character and hash it. Then it should find the previous word, change a few variable addresses, and switch to compilation mode.

In my case, I also want to create a lookup table for Forth words which indexes them by length. I didn't really think that through so I'll get to that later.

Before we continue, I wanted to add more working registers for function parameters and return arguments:

```
+# a1 = X   = working register
+# a2 = Y   = working register
+# a3 = Z   = working register
```

### Reading the first word

The word we read will be called a `token`. Unlike [sectorforth](https://github.com/cesarblum/sectorforth/blob/32031ac6e77e30817c2f65ba11b1ccda07d564f9/sectorforth.asm#L354-L423), we're not processing terminal/key entry data as we read the token. Instead, we expect the terminal input buffer to already contain the token, somewhere. This means we won't need to check for non-printable ASCII characters or comments because they'll have already been validated before being added to the buffer. Here's how it should work:

1. Skip all whitespaces until a non-whitespace character is found.
2. Increment the word's length by 1 for each character.
3. Skip all characters until a whitespace is found.
3. Return the word's length and start address of the token.
4. If the buffer runs out while we're seaching for characters, return with 0 length.

This approach was used in [derzforth](https://github.com/theandrew168/derzforth/blob/4542c4c43388e8b647fd5183f89eb65c12a17fac/derzforth.asm#L123-L152) but the code was confusing and non-optimal. I've attempted to improve it and ended up rewriting the entire thing:

```
token:
    li t1, 0x32                 # initialize temporary to 'space' character
    li t2, 0                    # initialize temporary counter to 0
token_char:
    blt a1, a0, token_done      # compare the address of TOIN with the address of TIB
    lbu t0, 0(a1)               # read char from TOIN address
    addi a1, a1, -1             # move TOIN pointer down
    bgeu t1, t0, token_space    # compare char with space
    addi t2, t2, 1              # increment the token size for each non-space byte read
    j token_char                # loop to read the next character
token_space:
    beqz t2, token_char         # loop to read next character if token size is 0
    j token_done                # token reading is done
token_done:
    add a0, a1, t2              # add the size of the token with the address of TOIN to W
    addi a0, a0, 1              # add 1 to W to account for TOIN offset pointer
    mv a1, t2                   # store the size in X
    ret
```

This `token` function is called in the `COLON` definition below:

```
defcode ":", 0x0102b5df, COLON, LATEST
    li a0, TIB          # load TIB into W
    li a1, TOIN         # load TOIN into X
    lw a1, 0(a1)        # load TOIN address value into X
    call token
```

The `COLON` definition is not complete, since I'll need to store the new `TOIN` address (a0) in the variable, and then continue processing things.

### Closing thoughts

Writing this `token` code took a few days and quite a few iterations to get right, but I'm happy with the result since it's short and reads fairly easily. I also have a cold so it has been difficult to focus on this task.

In the next session, once I'm fully recovered, I'll continue working on `COLON` with the goal of completing it.
