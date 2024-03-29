##
# GD32VF103
##

.equ CELL, 4                            # 32-bits cell size
.equ RAM_BASE, 0x20000000               # base address of RAM
.equ STACK_SIZE, 256                    # 256 Bytes

# UART
.equ USART0_BASE_ADDRESS, 0x40013800
.equ UART_RX_STATUS, 0x00       # USART status register offset (USART_STAT)
.equ UART_RX_DATA, 0x04         # data register offset (USART_DATA)
.equ UART_TX_STATUS, 0x00       # USART status register offset (USART_STAT)
.equ UART_TX_DATA, 0x04         # data register offset (USART_DATA)
.equ UART_RX_BIT, (1 << 5)      # read data buffer not empty bit (RBNE)
.equ UART_TX_BIT, (1 << 7)      # transmit data buffer empty bit (TBE)d

.balign CELL
# Initialize the UART
uart_init:
    # enable the RCU clocks
    li t0, 0x40021000                       # load base address of the RCU
    lw t1, 0x18(t0)                         # load value from the APB2 enable register (RCU_APB2EN)
    li t2, (1 << 14) | (1 << 2) | (1 << 0)  # set USART0EN (bit 14), PAEN (bit 2), AFEN (bit 0)
    or t1, t1, t2                           # add the enabled bits to the existing RCU_APB2EN value
    sw t1, 0x18(t0)                         # store value in RCU_APB2EN register at offset 0x18

    # set the baud rate: USARTDIV = frequency (8 MHz) / baud rate (115200 bps)
    li t0, 0x40013800                       # load USART0 base address
    li t1, ((8000000/115200) & 0x0000fff0) | ((8000000/115200) & 0x0000000f) # load baud rate divider
    sw t1, 0x08(t0)                         # store the value in the Baud rate register (USART_BAUD)

    # set the stop bits
    li t1, (0 << 12) | (0 << 13)            # set STB (bits 12 and 13) to 00 (1 stop bit)
    sw t1, 0x10(t0)                         # store the value in the USART Control register 1 (USART_CTL1)

    # disable hardware flow control, half-duplex, etc
    sw zero, 0x14(t0)                       # store the value in the USART Control register 2 (USART_CTL2)

    # enable receiver, transmitter, uart, interrupts
    li t1, (1 << 2) | (1 << 3) | (1 << 5) | (1 << 6) | (1 << 7) | (1 << 13) # set REN, TEN, RBNEIE, TCIE, TBEIE, UEN bits to 1
    sw t1, 0x0C(t0)                         # store the value in the USART Control register 0 (USART_CTL0)

uart_done:
    ret

.balign CELL
# Initialize the GPIO
gpio_init:
    # configure TX on pin 9 of port A (0b1011)
    li t0, 0x40010800                       # load base address of GPIOA
    lw t1, 0x04(t0)                         # load value from the Port control register 1 (GPIOA_CTL1)
    li t2, 0xfffff00f                       # load bitmask to clear 8 bits (MD9[1:0],CTL9[1:0],MD10[1:0],CTL10[1:0])
    and t1, t1, t2                          # clear the bits (TX 4,5,6,7) and (RX 8,9,10,11)
    or t1, t1, (1 << 4) | (1 << 5) | (0 << 6) | (1 << 7) # set the bits 4,5,6,7 (afio push-pull, max speed 50MHz)

    # configure RX on pin 10 of port A (0b0100)
    li t2, (0 << 8) | (0 << 9) | (1 << 10) | (0 << 11)  # load the bits 8,9,10,11
    or t1, t1, t2                           # set the bits 8,9,10,11 (input floating, mode)
    sw t1, 0x04(t0)                         # store the value in the Port control register 1 (GPIOA_CTL1)

gpio_done:
    ret
