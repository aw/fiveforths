# December 7, 2022

1. [Log 15](#log-15)
2. [Initializing UART pt2](#initializing-uart-pt2)
3. [Closing thoughts](#closing-thoughts)

## Log 15

The goal today is to continue with the UART initialization and validate the register values in `GDB`.

### Initializing UART pt2

After enabling the clocks, the next step is to set the baud rate for `USART0`. From the [GD32VF103 manual](https://dl.sipeed.com/LONGAN/Nano/DOC/GD32VF103_User_Manual_EN_V1.2.pdf), we can find the base address of `USART0` to be `0x4001 3800`, and the _Baud rate register_ is at offset `0x08`, let's remember that for later.

Since we haven't configured the device other than enabling some clocks, it's a good idea to confirm the current clock speed by reading the _RCU Control register_ at address `0x4002 1000` with offset `0x00`:

```
(gdb) x/t 0x40021000+0x00
0x40021000:	00000000000000000110001010000011
```

Let's clear up that formatting:

```
00000000 00000000 01100010 10000011
```

According to the above user manual:

* bit 0 means the internal 8MHz oscillator (IRC8M) is enabled
* bit 1 means it's stable
* bit 16 means the external high speed oscillator (HXTAL) is disabled

Let's also read the _Clock register 0_ at offset `0x04`:

```
(gdb) x/t 0x40021000+0x04
0x40021004:	00000000000000000000000000000000
```

All zeroes! What this means is all the clocks are running at 8MHz with the internal oscillator, so we'll use that to calculate the baud rate divider for our 115200 bauds (symbols per seconds) setting. In the future we might want to bump that to the max 108MHz using the external oscillator. Let's continue with `uart_init:`

```
    # set the baud rate: USARTDIV = frequency (8 MHz) / baud rate (115200 bps)
    li t0, 0x40013800   # load USART0 base address
    li t1, (8000000/(115200 * 16) << 4) | (8000000/(115200 * 16))
    sw t1, 0x08(t0)     # store the value in the Baud rate register (USART_BAUD)
```

And when we inspect with `GDB`:

```
(gdb) x/th 0x40013800+0x08
0x40013808:    0000000001000100
(gdb) x/x 0x40013800+0x08
0x40013808:    0x0044
```

Now let's explain what just happened there. Once again, according to the above user manual, there is a way to calculate the `USARTDIV` in order for the MCU to generate the baud rate we want. The method is somewhat complex and is usually satisfied by a simpler `frequency / baud rate`. However I wanted to do it "correctly" so I used the above formula, which isolates the first 4 bits (`0:3`) as the fractional part, and the next 12 bits (`4:15`) by shifting the integer part (12 bits) to the left by 4 (`2^4)`) because those 12 bits are in position `4:15` not `0:11`. Finally it performs a bitwise `OR` of the integer and fraction in order to give us the exact value to be stored in the _Baud rate register_.

When we examine the memory address `0x40013800` at the offset `0x08`, we can see the result is exactly `0x0044`. I know, I could have just hardcoded `0x0044` but that would make it much more difficult to change the frequency/baud rate in the future.

### Closing thoughts

I'll end this session here. Next time I'll setup the `data/stop/parity/mode/flowctrl` bits in the _USART Control register_ and maybe finally configure the GPIOs.
