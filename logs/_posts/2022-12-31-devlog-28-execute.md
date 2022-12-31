# December 30, 2022

1. [Log 28](#log-28)
2. [Fixing NEXT](#fixing-next)
3. [Execute](#execute)
4. [Fixing newlines](#fixing-newlines)
5. [Closing thoughts](#closing-thoughts)

### Log 28

In this session I'll start by fixing the `NEXT` macro and then I'll implement the `execute` function.

### Fixing NEXT

Of course I had a feeling `NEXT` was wrong, because it was copied blindly from _derzforth_ and has never been tested. However it may actually be correct afterall, but I'm not sure so let's just move forward this these changes.

The previous `NEXT` macro looked like this:

```
.macro NEXT
    lw a0, 0(s1)        # load memory address from IP into W
    addi s1, s1, CELL   # increment IP by CELL size
    lw t0, 0(a0)        # load memory address from W into temporary
    jr t0               # jump to the address in temporary
.endm
```

The new version looks like this:

```
.macro NEXT
    mv a0, s1           # load memory address from IP into W
    addi s1, s1, CELL   # increment IP by CELL size
    jr a0               # jump to the address in W
.endm
```

It's a bit simpler, in fact what changed is that it now makes a direct jump to the memory address stored in the `IP` register (`s1`). I believe the approach used by _derzforth_ is to perform a double-indirect jump, which is why it was loading an address from an address in the `IP` register. I'm not sure why it does that, since _sectorforth_ performs a direct jump and _jonesforth_ only a single indirect jump...

### Execute

Now with `NEXT` "fixed" (I think?), we should be able to _execute_ words (interpret them), so let's define `execute` here:

```
execute:
    la s1, ok               # load the address of the interpreter into the IP register
    addi a0, a1, 2*CELL     # increment the address of the found word by 8 to get the codeword address
    lw t0, 0(a0)            # load memory address from W into temporary
execute_done:
    jr t0                   # jump to the address in temporary
```

The first thing is to load the `ok` function's address into the `IP` register. Then we increment our found word from the `X` register (`a1`) by 2 CELLs, because that's where we'll find the _codeword_ address.

Then we load that codeward memory address into a temporary `t0` and jump to it.

I know this is probably wrong in many ways, but it seems to somewhat work for a single token. I think that's because of a bug in my token processing algorithm, which I'll look at in another session.

### Fixing newlines

I discovered a small issue with newlines in the `interpreter` function. The first piece of code was checking if the character was a comment. The `checkchar` macro would perform a `call uart_get` immediately followed by a `call uart_put`, which was problematic because upon reading a _newline_ it would.. send a newline to the REPL! It looked like this:

```
nope
 ?
state
 ok
```

To fix this, i replaced that specific macro call with the expanded form, but added some code before the `call uart_put`. The code first checks if it's a _newline_, if yes it skips the `call uart_put` and jumps to checking if it's a comment. Otherwise it will `call uart_put` and then check if it's a comment:

```
+    call uart_get                               # read a character from UART
+    li t4, CHAR_NEWLINE                         # load newline into temporary
+    beq a0, t4, skip_send                       # don't send the character if it's a newline
+    call uart_put                               # send the character to UART
+
+skip_send:
     # validate the character which is located in the W (a0) register
-    checkchar CHAR_COMMENT, skip_comment        # check if character is a comment
+    li t0, CHAR_COMMENT                         # load comment character into temporary
+    beq a0, t0, skip_comment                    # skip the comment if it matches
```

Now when I type an invalid word in the REPL, I see a `?`, or an `ok` if the word is valid - on the same line. Like this:

```
nope ?
state ok
```

### Closing thoughts

Now I can execute ONE word (ex: `state`), but still can't compile. I also can't execute TWO ore more words (ex: `tib tib +`). In the next session I'll focus on fixing the bug in code execution (hopefully it's not related to the direct jump, but most likely it is haha), and then I'll jump to compiling words.
