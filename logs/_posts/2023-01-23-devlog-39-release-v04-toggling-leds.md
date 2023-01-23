# January 23

1. [Log 39](#log-39)
2. [Release v04](#release-v04)
3. [Toggling LEDs](#toggling-leds)
4. [Closing thoughts](#closing-thoughts)

### Log 39

In this session I'll discuss the [latest release](https://github.com/aw/fiveforths/releases/tag/v0.4) which includes handling HEX numbers and manipulating hardware.

### Release v04

One of the major obstacles to working with hardware was the lack of support for hexadecimal numbers. That is, inputting something like `0xCAFE4241` would be treated as a string (and word not found). Back in the day, older _Forths_ would set the base value using a word such as `HEX` or `DECIMAL` or even `OCTAL`. I think this is completely unnecessary and much more elegant to simply prefix a number with the number base `0x`. It also prevents problems where one might forget to set the base back to what it previously was. Decimal is the default base for numbers, and octal can be ignored (or implemented in Forth). Binary input might be added in the future, with the `0b` prefix, but I don't think it's very important for now.

More importantly, when browsing through the CPU datasheet, we'll typically (always) find memory addresses given in hexadecimal values, so let's support that.

First, in our internal `number` function after checking if the number is negative (prefixed with `-`), instead of jumping to `number_digit` we'll jump to `number_check` and see if it's hexadecimal (prefixed with `0x`):

```
number_check:
    li t3, 0x00007830           # load the '0x' string into temporary
    lhu t2, 0(a0)               # load the first 2 characters into temporary
    bne t2, t3, number_digit    # jump to number digit loop if the first 2 characters are not '0x'
```

We're using the `lhu` instruction to load a half-word (16 bits / 2 bytes), and then comparing those 2 bytes with the value `0x00007830` which just so happens to be `0x` when input through the UART. If there's no match, then we'll jump to the `number_digit` routine as usual. If there is a match, then we'll set the number base to `16` in a temporary register, and increment the buffer address by 2 to skip the `0x` characters. We jump to `number_error` if the string is only 2 characters and equal to `0x`. This doesn't actually return an error / reset things. All it does is adjust the return value in the `X` working register so when the function returns, we'll know it's not a number (maybe `0x` is a word? why not?).

In `number_digit`, we're doing things a bit differently to check if the digits are valid. We want to ensure they're between `0-9` if the base is 10, and between `0-F` if the base is 16. Unfortunately in ASCII the letters `A-F` don't immediately follow `9` or precede `0`, so a bit of funky math is required. The exact approach is explained very well in the Forth book _"Threaded Interpretive Languages (1981)"_, but luckily for us it was also implemented in [jonesforth](https://github.com/nornagon/jonesforth/blob/master/jonesforth.S#L1453-L1481). Even better, an existing _QEMU jonesforth RISC-V port_ [also implemented this approach](https://github.com/jjyr/jonesforth_riscv/blob/master/jonesforth.S#L1552-L1579) in Assembly, so I inspired myself from those two and made some modifications to work in [FiveForths](https://github.com/aw/fiveforths/blob/master/src/05-internal-functions.s#L77-L107).

The final change was to change the return type for the `X` register. Previously a `1` meant `OK` and a `0` meant `ERROR`. I changed it so `0` means `OK` and anything greater than that means `ERROR`. The reason is the `X` register (`a1`) starts off holding the size of the token, and while processing each digit we decrement that size until it reaches `0`. Although if we detect a non-digit (ex: `G` or `$`) then it's definitely not a number, so we end the routine there, leaving `X` at its last value, which will ultimately be greater than `0` (thus, an error). If the value of `X` is `0` at the end of the routine, we know for sure we have a valid number, which we store in the `W` working register (`a0`).

Of course in the interpreter when `call number` returns, we need to check if `X` was `zero` instead:

```
-    bnez a1, push_number    # push the token to the stack or memory if it's a number
+    beqz a1, push_number    # push the token to the stack or memory if it's a number
```

That's a small but crucial change.

### Toggling LEDs

Now that we can input hexadecimal numbers, it becomes much easier to mess with the hardware. Our _Hello World_ for _FiveForths_ involves toggling the blue (pin A1) and green (pin A2) LEDs.

Before we start, it's important to define some words which will be used later:

```
: invert -1 nand ;
: over sp@ 4 + @ ;
: swap over over sp@ 12 + ! sp@ 4 + ! ;
: and nand invert ;
: or invert swap invert nand ;
```

Now here's the Forth code to turn on the green and blue LEDs on the _Longan Nano_:

```
: green_led_on 0x40010800 @ 0xFFFFFF0F and 0x00000030 or 0x40010800 ! ;
: blue_led_on 0x40010800 @ 0xFFFFF0FF and 0x00000300 or 0x40010800 ! ;
green_led_on
blue_led_on
```

Here's what the code actually does:

* read the current GPIOA port config (with `@`)
* apply a mask to clear the 4 bits for pin the (with `and`)
* apply the new pin config (with `or`)
* store the new GPIOA port config (with `!`)
* execute the new word to turn on the LED

And here's an explanation of the hexadecimal values:

* `0x40010800`: GPIOA base address with offset `0x00` for `CTL0` pins 0-7 (would be `CTL1` with offset `0x04` for pins 8-15).
* `0xFFFFF0FF`: mask to clear GPIO pin 2 (would be the same for GPIO pin 10, while GPIO pin 1 would be `0xFFFFFF0F` and GPIO pin 8 would be `0xFFFFFFF0`).
* `0x00000030`: GPIO pin 1 setting `0b0011` which is `push-pull output, max speed 50MHz`.
* `0x00000040`: GPIO pin 1 setting `0b0100` which is `floating input`.
* `0x00000300`: GPIO pin 2 setting `0b0011` which is `push-pull output, max speed 50MHz`.
* `0x00000400`: GPIO pin 2 setting `0b0100` which is `floating input`.

Now to turn off the LEDs is equally simple:

```
: green_led_off 0x40010800 @ 0xFFFFFF0F and 0x00000040 or 0x40010800 ! ;
: blue_led_off 0x40010800 @ 0xFFFFF0FF and 0x00000400 or 0x40010800 ! ;
green_led_off
blue_led_off
```

Notice here in the definitions all we changed is the value of the GPIO pin settings. We're switching the GPIO pins back to `floating input` mode, which essentially is like turning off the LEDs (technically the LEDs are active-low, so turning them "on" requires us to bring the pins low).

I think this shows some of the stronger points of writing in Forth as opposed to Assembly, and it's nice being able to do it interactively and see the results right away.

### Closing thoughts

I'll be focusing on other projects moving forward, so I don't expect to add any new features or enhancements anytime soon, or at least until those projects are completed. Thanks for following along!
