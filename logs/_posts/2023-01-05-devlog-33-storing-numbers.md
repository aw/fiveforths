# January 05, 2023

1. [Log 33](#log-33)
2. [Storing numbers](#storing-numbers)
3. [Closing thoughts](#closing-thoughts)

### Log 33

I know I promised I would get to compile words, but that's hard so instead in this session i'll add the ability to store numbers on the stack. Once that works then I'll get to compiling words hahaha.

### Storing numbers

The `number` routine has already been written in `src/05-internal-functions.s`, but we had no code to call it. Unlike most **Forths**, I don't want to check if it's a number _after_ checking if it's a known word. That concept seems strange to me. For starters, we already know what a number will look like. Since we're only dealing with `base 10` numbers for the moment, we can define a number as "a series of digits optionally prefixed by a minus sign".

In that case, I'd rather we scan for a number _before_ calling `djb2_hash`.

One oversight is the registers need to be saved before calling `number`, because it clobbers the `a0` and `a1` registers. I could fix this but I'll save that for the optimization step. For now, let's just save/restore them:

```
    # check if the token is a number
    mv t5, a0               # save a0 temporarily
    mv t6, a1               # save a1 temporarily
    call number             # try to convert the token to an integer
    bnez a1, push_number    # push the token to the stack if it's a number
    mv a0, t5               # restore a0
    mv a1, t6               # restore a1
```

Here we're saving the `W` and `X` working registers to temporary registers, and then calling `number`, which will return the result of the operation in `X`. If the result is not `0` (ex: `1`), then we have a valid number so we'll call `push_number` to store the number (stored in `W`) on the stack:

```
push_number:
    PUSH a0                 # push the W working register to the top of the data stack
    j process_token         # jump back to process the next token
```

This then jumps right back to processing the next token, completely skipping the hash/lookup/compile/execute steps. Let's try adding numbers and a variable to the stack in the terminal:

```
-2147483648 -2147483649 state 4294967296 -100 100 12345 -31234567<Enter>
```

A few notes: `-2147483649` should translate to `2147483647` as mentioned in _devlog 26_. The `state` variable will be its address, which is `0x20004cfc` (or decimal `536890620`), and `4294967296` should translate to `0`. Let's check in `GDB`, starting at the top of the stack and going down by 32 bytes (4 bytes x 8 values):

```
(gdb) x/8dw 0x20005000-32
0x20004fe0:	-31234567	12345	100	-100
0x20004ff0:	0	536890620	2147483647	-2147483648
```

Great! That works just as expected. Now we can store numbers on the stack, and non-numbers will be hashed and searched for in the dictionary.

### Closing thoughts

Well that was easier than expected, let's just hope I didn't make a fatal mistake.. but so far it seems to work fine. In the next session I have no other choice but to jump to the _compile_ mode and try to get that working. It might require a review of `COLON` and `SEMI`... we'll see.
