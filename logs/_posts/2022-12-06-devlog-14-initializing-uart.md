# December 6, 2022

1. [Log 14](#log-14)
2. [Initializing UART](#initializing-uart)
3. [Closing thoughts](#closing-thoughts)

## Log 14

I've finally made it to the I/O part. I want to do this before the interpreter, just to be sure I can actually communicate with the Longan Nano MCU.

### Initializing UART

The Longan Nano MCU contains a few `UARTs` and `USARTs`. In my case I want to use `USART0` but i'll use it in its simplest form which only requires wiring the usual `RX/TX` GPIO data pins. The default configuration will be _asynchronous full-duplex with 8 data bits, no parity, 1 stop bit, no flow control, at 115200 bauds_.

First, we'll need to configure the UART and setup the GPIO pins before we can actually use it. This is an initialization task where we set some bits at different memory addresses.

Before we start setting bits like a cowboy, let's have a quick look at what exactly is stored in memory:

```
(gdb) x/1tw 0x40021000+0x18
0x40021018:	00000000000000000000000000000000
```

I used the command `x` to examine the contents of a memory address. I specified the parameters `1tw` to display `1` `w`ord (4 bytes) in binary (`t`). That address is `0x40021000`, which is the _RCU base address_ (Reset and Clock Unit) plus the offset `0x18`, which is the _APB2 enable register_. That register lets us enable things such as ADC, SPI, and of course, `USART0`.

Notice it's all set to 0. It might not always be, so first let's load that memory address into a temporary:

```
# Initialize the UART
uart_init:
    li t0, 0x40021000   # load base address of the RCU
    lw t1, 0x18(t0)     # load value from the APB2 enable register (RCU_APB2EN)
```

Then we can enable the RCU clocks for the `USART, GPIO` and add it to the existing value (and store it back in memory):

```
    # enable the RCU clocks
    li t2, (1 << 14) | (1 << 2) # set USART0EN (bit 14), PAEN (bit 2)
    or t1, t1, t2       # add the enabled bits to the existing RCU_APB2EN value
    sw t1, 0x18(t0)     # store value in RCU_APB2EN register at offset 0x18

gpio_init:
```

Let's recompile using `make -B`, reload this in GDB, and add a breakpoint on `gpio_init`:

```
(gdb) load
</snip>

(gdb) break gpio_init
Breakpoint 3 at 0x80000d8: file fiveforths.s, line 207.

(gdb) c
Continuing.
</snip>

(gdb) x/1tw 0x40021000+0x18
0x40021018:	00000000000000000100000000000100
```

Perfect!

### Closing thoughts

In the next session, I'll focus on setting the baud rate by performing some clock division, and then maybe move to configuring the GPIO.
