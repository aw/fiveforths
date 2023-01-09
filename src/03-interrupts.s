##
# Interrupts
##

.text
.global _start
_start:
    j boot

.balign CELL
.global interrupt_handler
.type interrupt_handler, @function
# unimplemented interrupt handler for now
interrupt_handler:
    mret

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
