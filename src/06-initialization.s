##
# Initialization
##

# board boot initializations
boot:
    call interrupt_init # RISC-V interrupt CSR initialization
    call uart_init      # board specific UART initialization
    call gpio_init      # board specific GPIO initialization

    # initialize HERE variable
    li t0, RAM_BASE     # load RAM_BASE memory address
    li t1, HERE         # load HERE variable
    sw t0, 0(t1)        # initialize HERE variable to contain RAM_BASE memory address

    # initialize LATEST variable
    la t0, word_SEMI    # load address of the last word in Flash memory (;) for now
    li t1, LATEST       # load LATEST variable
    sw t0, 0(t1)        # initialize LATEST variable to contain word_SEMI memory address

    # display boot message
    la a1, msg_boot     # load string message
    addi a2, a1, 74     # load string length
    call uart_print     # call uart print function
    j reset

# reset the Forth stack pointers, registers, variables, and state
reset:
    # initialize stack pointers
    la sp, __stacktop           # initialize DSP register
    la s1, interpreter_start    # initialize IP register
    li s2, RSP_TOP              # initialize RSP register

    # initialize function parameters
    mv a0, zero         # initialize W register
    mv a1, zero         # initialize X register
    mv a2, zero         # initialize Y register
    mv a3, zero         # initialize Z register

    # initialize STATE variable
    li t0, STATE        # load STATE variable
    sw zero, 0(t0)      # initialize STATE variable (0 = execute)

.balign CELL
# reset the RAM from the last defined word
ram_init:
    li t0, HERE         # load HERE memory address
    lw t0, 0(t0)        # load HERE value
    li t1, PAD          # load PAD variable
ram_zerofill:
    # initialize the memory cells
    beq t0, t1,ram_done # loop until counter (HERE) == PAD
    sw zero, 0(t0)      # zero-fill the memory address
    addi t0, t0, CELL   # increment counter by 1 CELL
    j ram_zerofill      # repeat
ram_done:
    # continue to tib_init

.balign CELL
# reset the terminal input buffer
tib_init:
    # initialize TOIN variable
    li t0, TIB          # load TIB memory address
    li t1, TOIN         # load TOIN variable
    li t2, TIB_TOP      # load TIB_TOP variable
    sw t0, 0(t1)        # initialize TOIN variable to contain TIB start address
tib_zerofill:
    # initialize the TIB
    beq t2, t0,tib_done # loop until TIB_TOP == TIB
    addi t2, t2, -CELL  # decrement TIB_TOP by 1 CELL
    sw zero, 0(t2)      # zero-fill the memory address
    j tib_zerofill      # repeat
tib_done:
    j interpreter_start # jump to the main interpreter REPL

msg_boot: .ascii "FiveForths v0.2, Copyright (c) 2021~ Alexander Williams, https://a1w.ca \n\n"
