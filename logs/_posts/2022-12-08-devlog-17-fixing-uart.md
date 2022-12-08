# December 8, 2022

1. [Log 17](#log-17)
2. [Fixing UART](#fixing-uart)
3. [Closing thoughts](#closing-thoughts)

## Log 17

I made a mistake when configuring the `RX/TX` GPIO pins. This session's focus is on fixing that.

### Fixing UART

When reviewing the datasheet for the Longan Nano's MCU, I realized I made one mistake. The USART pins `RX/TX` are actually "alternate function" pins. This means I have some other bits in registers to set.

The first part to fix is in `uart_init` where we set some bits to enable the RCU clocks in `RCU_APB2EN`, we also need to enable the alternate function clock:

```
-    li t2, (1 << 14) | (1 << 2)             # set USART0EN (bit 14), PAEN (bit 2)
+    li t2, (1 << 14) | (1 << 2) | (1 << 0)  # set USART0EN (bit 14), PAEN (bit 2), AFEN (bit 0)
```

Now if we compare the register with what we had before:

```
(gdb) x/1tw 0x40021000+0x18
0x40021018:	00000000000000000100000000000100
(gdb) c
Continuing.

Breakpoint 2, gpio_done () at fiveforths.s:224
224	    ret
(gdb) x/1tw 0x40021000+0x18
0x40021018:	00000000000000000100000000000101
```

There's that extra 1 set in the least significant bit.

Next, in `gpio_init` we need to configure the GPIO output as "AFIO", so the `TX` pin should be set to `0b1011` (AFIO push-pull) instead of `0b0011` (GPIO push-pull):

```
-    or t1, t1, (1 << 4) | (1 << 5) | (0 << 6) | (0 << 7) # set the bits 4,5,6,7 (output push-pull, max speed 50MHz)
+    or t1, t1, (1 << 4) | (1 << 5) | (0 << 6) | (1 << 7) # set the bits 4,5,6,7 (afio push-pull, max speed 50MHz)
```

Let's compare with the previous register value:

```
(gdb) x/th 0x40010800+0x04
0x40010804:	0100010000110100
(gdb) c
Continuing.

Breakpoint 2, gpio_done () at fiveforths.s:224
224	    ret
(gdb) x/th 0x40010800+0x04
0x40010804:	0100010010110100
```

Looking good! Next I think it'll be a good idea to enable interrupts on the transmission and receive buffers. We'll modify the `uart_init` to also set the RBNEIE (receive buffer), TCIE (transmission complete), TBEIE (transmission buffer) interrupt enable bits to 1:

```
-    # enable receiver, transmitter, uart
-    li t1, (1 << 2) | (1 << 3) | (1 << 13)  # set REN (bit 2), TEN (bit 3), UEN (bit 13)
+    # enable receiver, transmitter, uart, interrupts
+    li t1, (1 << 2) | (1 << 3) | (1 << 5) | (1 << 6) | (1 << 7) | (1 << 13) # set REN, TEN, RBNEIE, TCIE, TBEIE, UEN bits to 1
```

And if we compare with the previous register values:

```
(gdb) x/th 0x40013800+0x0C
0x4001380c:	0010000000001100
(gdb) c
Continuing.

Breakpoint 2, gpio_done () at fiveforths.s:229
229	    ret
(gdb) x/th 0x40013800+0x0C
0x4001380c:	0010000011101100
```

The bits 5, 6, and 7 are now also set to 1.

### Closing thoughts

I enabled interrupts for the USART because I feel like it might be better to handle communication through that, instead of having a busy loop, but I'm not sure yet. In the next session I'll try to figure out which approach is better for this Forth use-case, and I'll try to get a test routine going to actually _test_ the USART.
