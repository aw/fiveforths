# December 25, 2022

1. [Log 24](#log-24)
2. [Checking numbers](#checking-numbers)
3. [Closing thoughts](#closing-thoughts)

### Log 24

What better way to spend _Christmas Afternoon_ than to write a cool function in `RISC-V Assembly`? (don't answer that.)

### Checking numbers

One _feature_ of Forth is its ability to check if a string token is actually a literal number, and then store it in memory as such.

I read quite a bit about this and decided to write my own simple number routine just for this use case. It seems this simple _feature_ was missing in _sectorforth_ and _derzforth_, which is fine but I kind of feel like it's quite important, and much better than doing something like:

```
: dup sp@ @ ;
: -1 dup dup nand dup dup nand nand ;
: 0 -1 dup nand ;
: 1 -1 dup + dup nand ;
: 2 1 1 + ;
... etc
```

What horror! My implementation doesn't handle various _bases_ like in _jonesforth_, but it's a good start and can be used later in the interpreter's main loop. The `number` function will accept 2 parameters, the `W` working register holds the start address of the token buffer, and the `X` working register holds the length (in bytes) of the token. The function then returns the signed integer in `W` and a flag in `X`. The flag will either be `1` for an `OK` result, or `0` for an `ERROR` result (ex: if the token is not a number).

To start, I want numbers to be a maximum of 29 bits, which is about 9 ascii characters. Let's start the `number` function:

```
number:
    li t1, 9                    # initialize temporary to 9: log10(2^29) = 8 + 1 = max 9 characters
    bgtu a1, t1, number_error   # if token is more than 9 characters, it's too long to be an integer
```

The reason is I actually want to store a number with the 3 first flag bits. I'll use the currently unused _user-defined_ flag and set it to `1` if the value is a number, or `0` otherwise (the current default). This will make it _super easy_ to identify a number in memory as opposed to a word's memory address. For now, that means we'll limit the actual size of a number to 29 bits instead of 32. We want to quickly exit the loop if the token is too long, so we add a guard right at the start of the function.

Next, we want to initialize a few temporaries to some important values that we'll use throughout our number conversion loop:

```
    mv t0, zero                 # initialize temporary to 0: holds the final integer
    li t3, CHAR_MINUS           # initialize temporary to minus character '-'
    mv t4, zero                 # initialize temporary to 0: sign flag of integer
    li t5, 10                   # initialize temporary to 10: multiplier used to convert the number
```

Next, we want to check if the first character in the token is a _minus_ sign (`0x2D`). This tells us the number will be negative, so let's keep track of that if it is negative, or jump to our digit checking loop if it's positive:

```
    lbu t2, 0(a0)               # load first character from W working register
    bne t2, t3, number_digit    # jump to number digit loop if the first character is not a minus sign
    # first character is a minus sign, so the number will be negative
    li t4, 1                    # number is negative, store a 1 flag in temporary
    addi a0, a0, 1              # increment buffer address by 1 character
    addi a1, a1, -1             # decrease buffer size by 1
```

Now we enter our digit checking loop, which performs a few validations on the character we've loaded. The first thing to do in the loop is exit the loop if the buffer is 0:

```
number_digit:
    beqz a1, number_done        # if the size of the buffer is 0 then we're done
```

Next, we know the hex value of the `0` digit is `0x30` so we'll subtract that from the loaded character and then check the result. We want it to be `between 0 and 9`, so subtracting `0x30` will give us an actual number between 0 and 9, or something else:

```
    lbu t2, 0(a0)               # load next character into temporary
    addi t2, t2, -0x30          # subtract 0x30 from the character
    bltz t2, number_error       # check if character is lower than 0, if yes then error
    bgtu t2, t1, number_error   # check if character is greater than 9, if yes then error
```

See there, we load the character, subtract `0x30`, and then check if it's less than 0, or more than 9. In both cases it's an error and we jump to the `number_error` handler. Otherwise we've got a valid number and we can continue:

```
    mul t0, t0, t5              # multiply previous number by 10 (base 10)
    add t0, t0, t2              # add previous number to current digit
```

Here we're multiplying the previous value by 10, because we're using base 10 numbers and we want to essentially add a zero to the right of that digit. Then we add the loaded digit to that. Example: If we have ascii characters "12", then it'll become decimal `1`, then `10` (after multiplying by 10), then `12` (after adding 2). Easy!

Next we're simply moving the pointer for the token buffer and decreasing the buffer size, before looping again:

```
    addi a0, a0, 1              # increment buffer address by 1 character
    addi a1, a1, -1             # decrease buffer size by 1
    j number_digit              # loop to check the next character
```

Now let's assume we had an error, example the token was "2abc", then we'll end up here:

```
number_error:
    li a1, 0                    # number is too large or not an integer, return 0
    ret
```

All it does is return 0 (or false) indicating an error.

If it wasn't an error, then we'll end up here:

```
number_done:
    beqz t4, number_store       # don't negate the number if it's positive
    neg t0, t0                  # negate the number using two's complement
```

This does two things, first it checks if our number was positive or negative, which we set early in the `number` function. If it is negative, then it uses two's complement to negate the number. Otherwise it jumps to here:

```
number_store:
    li t1, (2^29)-1             # largest acceptable number size: 29 bits
    bgt t0, t1, number_error    # check if the signed number is larger than 29 bits
    mv a0, t0                   # copy final number to W working register
    li a1, 1                    # number is an integer, return 1
    ret
```

That's the final part of the function. It first loads the largest value of a 29 bit number, then performs a signed compare with the final number. If it doesn't fit, then we return an error. Otherwise we copy the number to the `W` register and return `1` in the `X` register.

### Closing thoughts

This was surprisingly fun and easy to write, and I'm actually surprised that it works as expected (I think?). In the next session, I'll focus on adding that to the interpreter's main loop and use it to validate tokens and store them correctly in memory.
