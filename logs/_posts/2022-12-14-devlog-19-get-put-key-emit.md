# December 14, 2022

1. [Log 19](#log-19)
2. [Minor UART fix](#minor-uart-fix)
3. [Major macro fix](#major-macro-fix)
4. [Get Put Key Emit](#get-put-key-emit)
5. [Closing thoughts](#closing-thoughts)

# Log 19

In this session I plan on completing the implementation of `get/put` functions for UART, as well as fixing the remaining 2 primitives `KEY` and `EMIT`.

### Minor UART fix

I noticed a small issue in the `uart_get_loop`, let's see if you can spot it:

```
lb a0, 0x04(t0)             # read character from data register (USART_DATA)
```

On a 32-bit RISC-V, the `lb` instruction "Loads a Byte" (8 bits) into a 32-bit register. This works fine, however `lb` is actually a _sign-extended_ operation. If we try to load the character `0xA9` (i.e: `©`), the 8-bit value will be extended to 32-bits like this: `0xffffffa9`. This is not ideal. What we really want is to _zero-extend_ the 8-bit value, so it looks like this: `0x000000a9`. Luckily it's a simple fix using `lbu` (Load Byte Unsigned) instead of `lb`:

```
lbu a0, 0x04(t0)            # read character (zero-extended) from data register (USART_DATA)
```

### Major macro fix

While reviewing the code, I realized I made a really big (and stupid) mistake in the `POP` and `PUSH` macros. I'm not sure what I was doing there, but they don't even make sense. I fixed them and I'll explain below:

```
# pop top of data stack to register and move DSP to TOS
.macro POP reg
    mv \reg, s3         # copy TOS to register
    lw s3, 0(sp)        # load DSP value to register
    addi sp, sp, CELL   # move the DSP up by 1 cell
.endm

# push register to top of stack and move TOS to DSP
.macro PUSH reg
    addi sp, sp, -CELL  # move the DSP down by 1 cell
    sw s3, 0(sp)        # store the value in the TOS to the top of the DSP
    mv s3, \reg         # copy register into TOS
.endm
```

The theory behind these macros is we want to provide a register as a parameter. That register will either hold a value to be stored in the `TOS` (PUSH), or it will hold a value received from the `TOS` (POP). In both cases, we need to move the stack pointer by 1 cell because we'll either be moving the current `TOS` to the top of the `DSP` (PUSH), or we'll be moving the value at the top of the `DSP` into the `TOS` (POP).

I have no idea how I ended up with the previous macros though. I guess the wrong assumption was that `s3` is always a memory address (nope).

Anyways I think the current version is correct now, so let's continue with the rest of the code.

### Get Put Key Emit

Before implementing `get/put`, I want to make them generic because they'll pretty much work the same way on every supported board/microcontroller (I think?). First I'll define some constants for the base address and the status/data registers:

```
.equ USART0_BASE_ADDRESS, 0x40013800
.equ UART_RX_STATUS, 0x00       # USART status register offset (USART_STAT)
.equ UART_RX_DATA, 0x04         # data register offset (USART_DATA)
.equ UART_TX_STATUS, 0x00       # USART status register offset (USART_STAT)
.equ UART_TX_DATA, 0x04         # data register offset (USART_DATA)
.equ UART_RX_BIT, (1 << 5)      # read data buffer not empty bit (RBNE)
.equ UART_TX_BIT, (1 << 7)      # transmit data buffer empty bit (TBE)d
```

These apply to the `GD32VF103` microcontroller. Now we can write our generic `get/put` functions in `fiveforths.s`:

```
uart_get:
    li t0, USART0_BASE_ADDRESS  # load USART0 base address
uart_get_loop:
    lw t1, UART_RX_STATUS(t0)   # load value from status register
    andi t1, t1, UART_RX_BIT    # load read data buffer not empty bit 
    beqz t1, uart_get_loop      # loop until ready to receive
    lbu a0, UART_RX_DATA(t0)    # read character (zero-extended) from data register
    ret

uart_put:
    li t0, USART0_BASE_ADDRESS  # load USART0 base address
uart_put_loop:
    lw t1, UART_TX_STATUS(t0)   # load value from status register
    andi t1, t1, UART_TX_BIT    # load transmit data buffer empty bit
    beqz t1, uart_put_loop      # loop until ready to send
    sb a0, UART_TX_DATA(t0)     # send character to data register
    ret
```

These are mostly identical to the _derzforth_ implementation (polling). I also used this opportunity to remove the `_test` function from `gd32vf103.s` and instead I simply call `uart_get` and `uart_put` in `fiveforths.s`:

```
# Test the UART functionality
# 1. get a character, 2. send the character back
main:
    call uart_get
    call uart_put
    j main
```

Now that `get/put` are working, let's finish the `KEY` and `EMIT` primitives.

In the `KEY` primitive, we first want to read a character from the UART. It'll be stored in the `W` (`a0`) register. Then we want to push it to the `TOS` (`s3`) top of stack register:

```
# key ( -- x )          Read 8-bit character from uart input
defcode "key", 0x0388878e, KEY, EXIT
    call uart_get       # read character from uart into W
    PUSH a0             # store character into TOS
    NEXT
```

In the `EMIT` primitive, we want to copy the character from `TOS` into the `W` register, and then send it over the UART:

```
# emit ( x -- )         Write 8-bit character to uart output
defcode "emit", 0x04964f74, EMIT, KEY
    POP a0              # copy TOS into W
    call uart_put       # send character from W to uart
    NEXT
```

### Closing thoughts

I'm happy I noticed the strange macro bug, and even happier that I've _finally_ completed all the keyword primitives loosely based on _sectorforth_.

Now pretty much the "only" thing remaining is the actual **Forth** interpreter loop and repl - compile/execute modes, skipping comments and parens, error handling... I guess I'll start on those in the next session.
