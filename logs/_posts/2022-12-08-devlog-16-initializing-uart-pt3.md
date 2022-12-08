# December 8, 2022

1. [Log 16](#log-16)
2. [Initializing UART pt3](#initializing-uart-pt3)
3. [Configuring GPIO](#configuring-gpio)
4. [Closing thoughts](#closing-thoughts)

## Log 16

I'm aiming to complete the UART and GPIO initialization in this session.

### Initializing UART pt3

Last time, we enabled the clocks and set the baud rate. Now we'll look at setting up the mode bits. We know the `USART0` mode settings are in the _Control registers_ at address `0x4001 3800` at offsets `0x0C`, `0x10`, and `0x14`, and we don't need to read them first because we always want to overwrite the UART configuration when we initialize it - discarding any previously configured settings.

We'll start by configuring _Control register 1_, which sets the _Stop bits_ to 1:

```
    li t1, (0 << 12) | (0 << 13) # set STB (bits 12 and 13) to 00 (1 stop bit)
    sw t1, 0x10(t0)     # store the value in the USART Control register 1 (USART_CTL1)
```

Technically it's not necessary since the default is `00` on reset. But this makes sure it'll always be `00` during init, in the event it was previously configured to something else (not on reset).

Next we'll disable hardware flow control, half-duplex, etc in _Control register 2_:

```
   sw zero, 0x14(t0)   # store the value in the USART Control register 2 (USART_CTL2)
```

Finally we'll configure _Control register 0_, which enables the _Receiver_, _Transmitter_, and _USART_:

```
    li t1, (1 << 2) | (1 << 3) | (1 << 13) # set REN (bit 2), TEN (bit 3), UEN (bit 13)
    sw t1, 0x0C(t0)     # store the value in the USART Control register 0 (USART_CTL0)

uart_done:
    ret
```

Now let's examine the registers in memory to see if it's all set accordingly. We'll only look at the first 16 bits because the rest are all reserved bits:

```
(gdb) x/th 0x40013800+0x10
0x40013810:	0000000000000000
(gdb) x/th 0x40013800+0x14
0x40013814:	0000000000000000
(gdb) x/th 0x40013800+0x0C
0x4001380c:	0010000000001100
```

OK! That's exactly what we wanted. I know some might think there's some un-necessary initialization code here, but we have to remember that UART init might not always/only occur when the device is reset. I want to keep the door open for reinitializing it with different settings in the future, without requiring much head-scratching or code changes.

### Configuring GPIO

Now I want to configure the GPIO pins to handle `RX/TX`. We're using pins 9 (TX) and 10 (RX) on the GPIO port A. Their configuration is stored at address `0x4001 0800` at offset `0x04`. First we'll load the current values from memory:

```
gpio_init:
    # configure TX on pin 9 of port A (0b0011)
    li t0, 0x40010800                       # load base address of GPIOA
    lw t1, 0x04(t0)                         # load value from the Port control register 1 (GPIOA_CTL1)
```

Then we'll need to define a bitmask to clear the bits we want to modify, and we'll clear them:

```
    li t2, 0xfffff00f                       # load bitmask to clear 8 bits (MD9[1:0],CTL9[1:0],MD10[1:0],CTL10[1:0])
    and t1, t1, t2                          # clear the bits (TX 4,5,6,7) and (RX 8,9,10,11)
```

That sets 8 bits to 0, the 8 bits used to configure and set the mode of the `RX/TX` pins. Next I do something a bit weird, but again it's somewhat future-proofing the Assembly code:

```
    or t1, t1, (1 << 4) | (1 << 5) | (0 << 6) | (0 << 7) # set the bits 4,5,6,7 (output push-pull, max speed 50MHz)
```

This sets the 4 bits for `TX` to 0 or 1 depending on the setting we want. I'm looking to set it to `0b0011`, there the two least significant bits are 1 and 1 (from the right). In the future it'll be easy to change those configs and modes by simply changing the 0 or 1 values above.

Next we dosomething similar for `RX`, except it's configured with slightly higher values so they can't be used as an immidate. This means we'll need to store it in a register before applying it. The value to store is `0b0100` where the first two least significant bits are 0 and 0 (from the right):

```
    # configure RX on pin 10 of port A (0b0100)
    li t2, (0 << 8) | (0 << 9) | (1 << 10) | (0 << 11)  # load the bits 8,9,10,11
    or t1, t1, t2                           # set the bits 8,9,10,11 (input floating, mode)
    sw t1, 0x04(t0)                         # store the value in the Port control register 1 (GPIOA_CTL1)

gpio_done:
    ret
```

The final line stores the entire 32-bit value back into the register, and our USART GPIO pins should be fully configured now. We can examine the low 16-bits value in memory:

```
(gdb) x/th 0x40010800+0x04
0x40010804:	0100010000110100
```

Let's cleanup the formatting there:

```
0100 0100 0011 0100
```

We can see bits 4 and 5 are set to 1, as expected, and bit 10 is also set to 1. The other values remain unchanged since we performed a bitwise `OR` to store them.

### Closing thoughts

Well that was somewhat less exciting than I expected. I'm happy the USART and GPIO are fully configured, but I still don't know if it's _correct_ until I actually try to communicate over the UART. I'll reserve that for the next session though.
