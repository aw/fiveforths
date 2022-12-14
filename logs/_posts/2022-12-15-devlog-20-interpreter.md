# December 15, 2022

1. [Log 20](#log-20)
2. [Fixme](#fixme)
3. [Error handling](#error-handling)
4. [More initialization](#more-initialization)
5. [Interpreter](#interpreter)
6. [Closing thoughts](#closing-thoughts)

# Log 20

I didn't realize but it's been exactly 1 month since I've reloaded this project and started hacking on it again. I'm quite happy with the progress so far, even though I only dedicate a couple hours per session to this project.

This session's focus is on starting to make something that looks like a **Forth** interpreter.

### Fixme

Before I start on the interpreter, let's get rid of a few `# FIXME` comments in the code (and actually fix them).

The first are a couple of missing bounds checks in `COLON`. First we want to ensure our token size is never larger than 32 characters because we only have 5 bits to store the size (`2^5`).

```
    li t0, 32           # load max token size  (2^5 = 32) in temporary
    bgtu a1, t0, error  # error if token size is greater than 32
```

Next, when we store a word, we need 3 available cells (link, hash, codeword). We want to check this _before_ we update any important values in memory:

```
    # bounds check on new word memory location
    addi t4, t2, 3*CELL # prepare to move the HERE pointer to the end of the word
    li t5, PAD          # load out of bounds memory address (PAD)
    bgt t4, t5, error   # error if the memory address is out of bounds
```

Incidentally, the out of bounds memory address is where our `PAD` starts, and the space required for the word will end exactly at the new `HERE` address.

Finally, we'll repeat this bounds check but only with 1 CELL, for the `exit` memory location (`SEMI`):

```
    # bounds check on the exit memory location
    addi t2, t2, CELL   # prepare to move the HERE pointer by 1 CELL
    li t3, PAD          # load out of bounds memory address (PAD)
    bgt t2, t3, error   # error if the memory address is out of bounds
```

Well in total those were a lot of changes for bounds check (and fixing a bug I discovered), but before we get to the interpreter let's add some UART code to the `error` function (another `# FIXME`).

### Error handling

I didn't try very hard for this one and simply copied exactly what _derzforth_ does:

```
# print an error message to the UART
error:
    li a0, ' '
    call uart_put
    li a0, '?'
    call uart_put
    li a0, '\n'
    call uart_put

    j reset
```

Once an error is hit, the next step is to reset everything, we need to reinitialize the stack pointers, variables, state, etc.. which is what we've done in the `reset` function, so let's just jump there.

### More initialization

In the `reset` function, there's a bit more initialization required. The main thing we were missing is zero-filling the terminal input buffer (`TIB`):

```
tib_init:
    # initialize TOIN variable
    li t0, TIB          # load TIB memory address
    li t1, TOIN         # load TOIN variable
    li t2, TIB_TOP      # load TIB_TOP variable
    sw t0, 0(t1)        # initialize TOIN variable to contain TIB start address
tib_zerofill:
    # initialize the TIB
    beq t2, t0,tib_done # loop until TIB_TOP == TIB
    addi t2, t2, -CELL  # decrement TIB_TOP by 1 CELL
    sw zero, 0(t2)      # zero-fill the memory address
    j tib_zerofill      # repeat
tib_done:
    j interpreter       # jump to the main interpreter REPL
```

This is somewhat different from _derzforth_ and _sectorforth_. In this case we're starting from the top of the `TIB` (highest memory address), and filling it with 1 CELL (4 bytes on 32-bit RISC-V), decrementing the memory address and then looping until the entire `TIB` is filled with zeros.

Since we only allocated a stack size of 256 Bytes for the `TIB`, that equates to just 64 CELLs (i.e: 64 loop iterations) to clear it out. It's reasonably fast.

We also need to make sure the `TOIN` variable gets reinitialized, so I just moved that part from `reset` to `tib_init`.

### Interpreter

OK so we've cleared up all our `# FIXME`s, now we can _jump_ to the interpreter (haha, see what I did there?).

Here's what I've got so far:

```
# here's where the program starts (the interpreter)
interpreter:
    call uart_get       # read a character from UART
    call uart_put       # send the character to UART

    # FIXME: validate the character
    j interpreter
```

Let's see.. how should this work?

The first thing we want to do is read a character and echo it back (so we can see what we're typing). Next, we want to validate the character by checking if it's a comment, backspace, or newline, and printable character. At each point we'll add the character to the terminal input buffer (`TIB`) until we've gotten a full word (token).

If we get a newline and we're currently compiling a word then we'll just ignore it until the semicolon is given. That will allow us to write multi-line definitions and even "upload" them via UART. If all is good, then we'll jump into the process to validate the token, hash it, search for it in the dictionary, and either execute or compile based on the `STATE` variable or immediate status of the word.

Whew, that's a mouthful but it's pretty straightforward. I think I'll need to write a `lookup` function but we'll defer that for later.

### Closing thoughts

So far quite a few changes were made in this session, a lot of code was re-organized and moved around, but everything still compiles and works perfectly so far (I think?).

I was going to get right into character validation, but I want to take a break to think more about this (and re-read my Forth books). I'll get back to character validation in the next session.
