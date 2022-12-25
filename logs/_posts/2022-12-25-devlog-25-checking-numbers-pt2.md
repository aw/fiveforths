# December 25, 2022

1. [Log 25](#log-25)
2. [Checking numbers pt2](#checking-numbers-pt2)
3. [Closing thoughts](#closing-thoughts)

### Log 25

After running some proper tests on my `numbers` function, I realized it's completely flawed in more than a few ways. In this session I plan on fixing those issues.

### Checking numbers pt2

Previously, I planned on only storing 29-bit numbers and reserving 3 bits for flags. The idea was to allow me to store a number as if it were a word by simply setting a 1-bit flag. However cool that may sound, in theory it wouldn't work because a number is a literal value. It doesn't make sense to treat it as a word - because it's not - and why lose 3 bits just for that?

Another issue is the minus sign was being counted as a character, so the actual number's length could not be more than 8 digits if it were negative.

Next, there was an issue when negating the 29-bit number, because `neg` works on the 32-bit word, not 29-bit, so the converted negative number was actually not always correct.

Finally, I somehow forgot to set the 3-bit flag values (`001`) in the number.. but anyways we'll get rid of that by converting to a 32-bit number and leaving it at that.

The first change we'll make is to extend the maximum token length:

```
-    li t1, 9                    # initialize temporary to 9: log10(2^29) = 8 + 1 = max 9 characters
-    bgtu a1, t1, number_error   # if token is more than 9 characters, it's too long to be an integer
+    li t1, 10                   # initialize temporary to 10: floor(log10(2^32)) = 9 + 1 = max 10 characters
+    addi t2, t1, 1              # initialize temporary to 11: max characters + 1 for minus sign
+    bgtu a1, t2, number_error   # if token is more than 11 characters, it's too long to be an integer
```

Here we know that a 32-bit number can only have a maximum of 10 digits, so we store that in `t1`, but we'll need one more for the optional minus sign, so we store that in `t2`. Then we change our comparison to check if the token is more than 11 characters. This seems a bit roundabout, but we'll re-use the 10 value later as our multiplier, and our _greater than_ bounds check.

Speaking of bounds check, we were previously using 2 instructions for that: `bltz` to check if a digit is less than `0`, and `bgtu` to check if it's greater than `9`. I replaced them with a single instruction that uses `bgeu` to perform both checks (it's an unsigned branch check, which I also used in `token`):

```
-    bltz t2, number_error       # check if character is lower than 0, if yes then error
-    bgtu t2, t1, number_error   # check if character is greater than 9, if yes then error
+    bgeu t2, t1, number_error   # check if character is < 0 or >= 10
```

Nice!

The final change was where we performed a bounds check on the number, the previous code was totally not what I expected, so I fixed it like this:

```
-    li t1, (2^29)-1             # largest acceptable number size: 29 bits
+    li t1, 0xFFFFFFFF           # load the largest acceptable number size: 32 bits
```

This is much simpler and easier to understand. That hex value is `2^32 - 1`.

### Closing thoughts

I guess with this new method of checking numbers, I'll be forced to use the traditional **Forth** approach of enclosing a literal with `[` and `]`. I didn't really want to add those primitives in assembly, but as I mentioned in _devlog 24_, I feel that handling numbers correctly - natively - is quite important as opposed to writing some weird Forth code to do that.

I'm looking forward to getting back to the interpreter implementation in the next session, assuming I don't discover more bugs in my `numbers` function.
