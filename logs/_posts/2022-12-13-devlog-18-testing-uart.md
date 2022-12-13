# December 13, 2022

1. [Log 18](#log-18)
2. [Testing UART](#testing-uart)
3. [Looping for UART](#looping-for-uart)
4. [Interrupt initialization](#interrupt-initialization)
5. [Closing thoughts](#closing-thoughts)

## Log 18

After a few days deliberating on the best implementation for interrupts, I decided not to implement them just yet. I did implement a short test routine and I'm happy to report my UART code works!!

### Testing UART

Before continuing, I wanted to be sure my UART works, so I borrowed the `getc/putc` code from [derzforth](https://github.com/theandrew168/derzforth) and made some changes to it. The test simply waits for a character, then sends it back.

The first thing is to load the base address of `USART0` register:

```
_test_uart:
    li t0, 0x40013800           # load USART0 base address
```

Next, I want a loop which checks the UART status register's `RBNE` bit to see if the read buffer is empty or not, if yes then it loops, if not empty then it reads the character using `lb` (load byte):

```
uart_get_loop:
    lw t1, 0x00(t0)             # load value from status register (USART_STAT)
    andi t1, t1, (1 << 5)       # load read data buffer not empty bit (RBNE)
    beqz t1, uart_get_loop      # loop until ready to receive
    lb a0, 0x04(t0)             # read character from data register (USART_DATA)
```

We do something similar to send the character back:

```
uart_put_loop:
    lw t1, 0x00(t0)             # load value from status register (USART_STAT)
    andi t1, t1, (1 << 7)       # load transmit data buffer empty bit (TBE)
    beqz t1, uart_put_loop      # loop until ready to send
    sb a0, 0x04(t0)             # send character to data register (USART_DATA)

    ret
```

In this case we check the `TBE` bit to see if the transmit buffer is empty or not, and then send the character back and return from the `_test` function.

Since most of the UART and GPIO code is specific to the `GD32VF103` microcontroller, I decided to move it to its own file named `gd32vf103.s` and then include it from `fiveforths.s`

```
# include board-specific functions
.include "gd32vf103.s"
```

This should make it slightly easier to port this Forth implementation to other boards. There's still a bit of hardcoding in some places, but I don't want to waste my time writing a bunch of generic code that might never be used. This is fine for now.

### Looping for UART

The above code works, but it would be nice if _every__ character I send over UART could be sent back. For this, we'll add a main loop (temporary) right after the call to `gpio_init`:

```
main:
    call _test_uart
    j main
```

### Interrupt initialization

I know I said I wouldn't implement interrupts, but I wanted to at least lay some ground work in advance.

The first step was to define an interrupt handler as the very first item in memory (at the top of the file after the constants and macros), in this case at `0x8000000`:

```
.balign CELL
.global interrupt_handler
.type interrupt_handler, @function
# unimplemented interrupt handler for now
interrupt_handler:
    mret
```

The interrupt handler does nothing for the moment except return using `mret`, which is a _machine mode_ return. From what I've read so far, that's how interrupt handlers should return.

In the future I might end up using a _vector table_ instead of a generic interrupt handler, and if I do then I'll simply replace the `interrupt_handler` with `vector_table` or something.. and define the vectors/addresses from there.

Next is to actually perform the interrupt setup, but in my case I don't want to use interrupts, so I'll start by explicitly disabling them (even though they're technically disabled on reset):

```
# Initialize the interrupt CSRs
interrupt_init:
    # disable global interrupts
    csrc mstatus, 0x08  # mstatus = 0x300

    # clear machine interrupt enable bits
    csrs mie, zero      # mie = 0x304

    # set interrupt handler jump address
    la t0, interrupt_handler
    csrw mtvec, t0      # mtvec = 0x305

    ret
```

The `interrupt_init` function is called right before `uart_init` and `gpio_init`. All it does is set some CSRs (control status registers) and it sets our earlier `interrupt_handler` as the default jump address (in case we enable interrupts later).

### Closing thoughts

There's quite a bit more code required to fully initialize the interrupts (when you want to use them), but it's rather complex, somewhat error-prone, and totally not necessary for the moment.

In the next session, I'll look into implementing proper `get/put` functions for UART, similar to what _derzforth_ does, and then i'll also complete the `KEY` and `EMIT` primitives, which should be fairly easy.
