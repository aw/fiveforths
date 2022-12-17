# December 15, 2022

1. [Log 21](#log-21)
2. [Bug fix](#bug-fix)
3. [Interpreter pt2](#interpreter-pt2)
4. [Closing thoughts](#closing-thoughts)

### Log 21

Resuming from the previous log entry (same day, different session). I'll focus on character validation this time.

### Bug fix

I quickly discovered a bug in the `ok` function I defined previously. When thinking about what should happen after we print `' ok\n'`, I realized that before jumping to the `interpreter`, some state should be reset.

However, jumping to the `reset` function is problematic because that would also reset the stack pointers (we only want that on _error_, not on _ok_).

What we need is to jump to `tib_init` so we only reset the terminal input buffer, which will then jump to the `interpreter`. Here's the new `ok` function:

```
# print an OK message to the uart
ok:
    li a0, ' '
    call uart_put
    li a0, 'o'
    call uart_put
    li a0, 'k'
    call uart_put
    li a0, '\n'
    call uart_put

    j tib_init          # jump to reset the terminal input buffer before jumping to the interpreter
```

### Interpreter pt2

The first thing I want to do is define some constants for key characters we'll be referencing:

```
##
# Interpreter constants
##

.equ CHAR_NEWLINE, '\n'         # newline character 0x0A
.equ CHAR_SPACE, ' '            # space character 0x20
.equ CHAR_BACKSPACE, '\b'       # backspace character 0x08
.equ CHAR_COMMENT, '\\'         # backslash character 0x5C
.equ CHAR_COMMENT_OPARENS, '('  # open parenthesis character 0x28
.equ CHAR_COMMENT_CPARENS, ')'  # close parenthesis character 0x29
```

This will make it clearer when validating the input characters.

Next, since there's a few characters we want to check for, let's create a new macro so we have less code to write:

```
# check a character
.macro checkchar char, dest
    call uart_get       # read a character from UART
    call uart_put       # send the character to UART

    # validate the character which is located in the W (a0) register
    li t0, \char        # load character into temporary
    beq a0, t0, \dest   # jump to the destination if the char matches
.endm
```

This macro simply reads and sends a character into the working register `a0`, then it compares it with the value sent as the `char` parameter. If it matches then it jumps to the address in the `dest` parameter.

We'll use this in the interpreter and in our skip functions, like this:

```
    checkchar CHAR_COMMENT, skip_comment            # check if character is a comment
```

And in `skip_comment`, we have the following code which loops until a newline is found, then jumps back to the interpreter:

```
skip_comment:
    checkchar CHAR_NEWLINE, interpreter             # check if character is a newline
    j skip_comment                                  # loop until it's a newline
```

We use similar code to check for `( -- )` style stack comments which begin with an opening parens and end with a closing one.

The backspace is also somewhat similar, except in this case we're going to simulate "erasing" a character (on screen), but we only want to _actually_ erase it if the `TOIN` variable is at a higher address than `TIB` (i.e: if a character is actually in the buffer):

```
process_backspace:
    # erase the previous character on screen by sending a space then backspace character
    li a0, ' '
    call uart_put
    li a0, '\b'
    call uart_put

    # erase a character from the terminal input buffer (TIB) if there is one
    beq a1, t2, interpreter                         # return to interpreter if TOIN == TIB
    addi a1, a1, -1                                 # decrement TOIN by 1 to erase a character
    sw a1, 0(t3)                                    # store new TOIN value in memory

    j interpreter                                   # return to the interpreter after erasing the character
```

At this point we're almost ready to add the character to the terminal input buffer (`TIB`), but first we need to verify if the character is a printable 8-bit character between `0x20` and `0x7E` inclusively. There's no reason for a word to contain non-printable characters such as tabs (`0x09`) or carriage return (`0x0D`), although we will allow a newline (`0x0A`) as that's our separation character when in _execute_ mode.

### Closing thoughts

This was a short session but I got a lot done. In the next session I'll work on adding the characters to the `TIB`, and then read the token, hash it, dictionary lookup, etc...
