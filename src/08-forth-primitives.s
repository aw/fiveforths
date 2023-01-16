##
# Forth primitives
##

.equ word_NULL, 0

# reboot ( -- )         # Reboot the entire system and initialize memory
defcode "reboot", 0x06266b70, REBOOT, NULL
    j err_reboot        # jump to reboot

# @ ( addr -- x )       Fetch memory at addr
defcode "@", 0x0102b5e5, FETCH, REBOOT
    lw t0, 0(sp)        # load the top of stack into temporary
    lw t0, 0(t0)        # load the value from the temporary (addr)
    sw t0, 0(sp)        # store the value back the top of stack (x)
    NEXT

# ! ( x addr -- )       Store x at addr
defcode "!", 0x0102b5c6, STORE, FETCH
    li t0, DSP_TOP-(2*CELL)     # load address of top of DSP with -8 offset (needs 2 CELLs)
    bgt sp, t0, err_underflow   # jump to error handler if stack underflow

    lw t0, 0(sp)        # load the DSP value (x) into temporary
    lw t1, CELL(sp)     # load the DSP value (addr) into temporary
    sw t0, 0(t1)        # store x into addr
    addi sp, sp, 2*CELL # move DSP up by 2 cells
    NEXT

# sp@ ( -- addr )       Get current data stack pointer
defcode "sp@", 0x0388aac8, DSPFETCH, STORE
    PUSH sp             # store DSP in the top of the stack
    NEXT

# rp@ ( -- addr )       Get current return stack pointer
defcode "rp@", 0x0388a687, RSPFETCH, DSPFETCH
    PUSH s2             # store RSP in the top of the stack
    NEXT

# 0= ( x -- f )         -1 if top of stack is 0, 0 otherwise
defcode "0=", 0x025970b2, ZEQU, RSPFETCH
    lw t0, 0(sp)        # load the DSP value (x) into temporary
    snez t0, t0         # store 0 in temporary if it's equal to 0, otherwise store 1
    addi t0, t0, -1     # store -1 in temporary if it's 0, otherwise store 0
    sw t0, 0(sp)        # store value back into the top of the stack
    NEXT

# + ( x1 x2 -- n )      Add the two values at the top of the stack
defcode "+", 0x0102b5d0, ADD, ZEQU
    li t0, DSP_TOP-(2*CELL)     # load address of top of DSP with -8 offset (needs 2 CELLs)
    bgt sp, t0, err_underflow   # jump to error handler if stack underflow

    POP t0              # pop DSP value (x1) into temporary
    lw t1, 0(sp)        # load DSP value (x2) into temporary
    add t0, t0, t1      # add the two values
    sw t0, 0(sp)        # store the value into the top of the stack
    NEXT

# nand ( x1 x2 -- n )   Bitwise NAND the two values at the top of the stack
defcode "nand", 0x049b0c66, NAND, ADD
    li t0, DSP_TOP-(2*CELL)     # load address of top of DSP with -8 offset (needs 2 CELLs)
    bgt sp, t0, err_underflow   # jump to error handler if stack underflow

    POP t0              # pop DSP value (x1) into temporary
    lw t1, 0(sp)        # load DSP value (x2) into temporary
    and t0, t0, t1      # perform bitwise AND of the two values
    not t0, t0          # perform bitwise NOT of the value
    sw t0, 0(sp)        # store the value into the top of the stack
    NEXT

# lit ( -- n )          Get the next word from IP and push it to the stack, increment IP
defcode "lit", 0x03888c4e, LIT, NAND
    lw t0, 0(s1)        # load the memory address from IP into temporary
    PUSH t0             # push the literal to the top of the stack
    addi s1, s1, CELL   # increment IP by 1 CELL
    NEXT

# exit ( r:addr -- )    Resume execution at address at the top of the return stack
defcode "exit", 0x04967e3f, EXIT, LIT
    POPRSP s1           # pop RSP into IP
    NEXT

##
# Forth I/O
##

# key ( -- x )          Read 8-bit character from uart input
defcode "key", 0x0388878e, KEY, EXIT
    call uart_get       # read character from uart into W
    PUSH a0             # store character into top of data stack
    NEXT

# emit ( x -- )         Write 8-bit character to uart output
defcode "emit", 0x04964f74, EMIT, KEY
    POP a0              # copy top of data stack into W
    call uart_put       # send character from W to uart
    NEXT

##
# Forth variables
##

# tib ( -- addr )       Store TIB variable address in top of data stack
defcode "tib", 0x0388ae44, TIB, EMIT
    PUSHVAR TIB
    NEXT

# state ( -- addr )     Store STATE variable address in top of data stack
defcode "state", 0x05614a06, STATE, TIB
    PUSHVAR STATE
    NEXT

# >in ( -- addr )       Store TOIN variable address in top of data stack
defcode ">in", 0x0387c89a, TOIN, STATE
    PUSHVAR TOIN
    NEXT

# here ( -- addr )      Store HERE variable address in top of data stack
defcode "here", 0x0497d3a9, HERE, TOIN
    PUSHVAR HERE
    NEXT

# latest ( -- addr )     Store LATEST variable address in top of data stack
defcode "latest", 0x06e8ca72, LATEST, HERE
    PUSHVAR LATEST
    NEXT

##
# Forth words
##

# : ( -- )              # Start the definition of a new word
defcode ":", 0x0102b5df, COLON, LATEST
    li t3, TOIN         # load TOIN variable into unused temporary register
    lw a0, 0(t3)        # load TOIN address value into temporary
    call token          # read the token

    # move TOIN
    add t0, a0, a1      # add the size of the token to TOIN
    sw t0, 0(t3)        # move TOIN to process the next word in the TIB

    # bounds checks on token size
    beqz a1, err_ok     # ok if token size is 0
    li t0, 32           # load max token size  (2^5 = 32) in temporary
    bgtu a1, t0, err_token # error if token size is greater than 32

    call djb2_hash      # hash the token

    # set the HIDDEN flag in the 2nd bit from the MSB (bit 30) of the hash
    li t0, F_HIDDEN     # load the HIDDEN flag into temporary
    or a0, a0, t0       # hide the word

    # copy the memory address of some variables to temporary registers
    li t0, HERE
    li t1, LATEST
    la a2, .addr        # load the codeword address into Y working register

    # load and update memory addresses from variables
    lw t2, 0(t0)        # load the new start address of the current word into temporary (HERE)
    lw t3, 0(t1)        # load the address of the previous word into temporary (LATEST)

    # bounds check on new word memory location
    addi t4, t2, 3*CELL # prepare to move the HERE pointer to the end of the word
    li t5, PAD-4        # load out of bounds memory address (PAD)
    bgt t4, t5, err_mem # error if the memory address is out of bounds

    # update LATEST variable
    sw t2, 0(t1)        # store the current value of HERE into the LATEST variable

    # build the header in memory
    sw t3, 0*CELL(t2)   # store the address of the previous word
    sw a0, 1*CELL(t2)   # store the hash
    sw a2, 2*CELL(t2)   # store the codeword address

    # update HERE variable
    sw t4, 0(t0)        # store the new address of HERE into the HERE variable

    # update STATE variable
    li t0, STATE        # load the address of the STATE variable into temporary
    li t1, 1            # set the STATE variable to compile mode (1 = compile)
    sw t1, 0(t0)        # store the current state back into the STATE variable
    NEXT

docol:
    PUSHRSP s1          # push IP onto the return stack
    addi s1, a0, CELL   # skip code field in W by adding 1 CELL, store it in IP
    NEXT

.addr:
    j docol             # indirect jump to interpreter after executing a word

# ; ( -- )              # End the definition of a new word
defcode ";", 0x8102b5e0, SEMI, COLON
    # unhide the word
    li t0, LATEST       # copy the memory address of LATEST into temporary
    lw t0, 0(t0)        # load the address value into temporary
    lw t1, CELL(t0)     # load the hash into temporary
    li t2, ~F_HIDDEN    # load the inverted HIDDEN flag into temporary
    and t1, t1, t2      # unhide the word
    sw t1, CELL(t0)     # write the hash back to memory

    # update HERE variable
    li t0, HERE         # copy the memory address of HERE into temporary
    lw t2, 0(t0)        # load the HERE value into temporary

    # bounds check on the exit memory location
    li t3, PAD-4        # load out of bounds memory address (PAD)
    bgt t2, t3, compile_error # error if the memory address is out of bounds

    la t1, code_EXIT    # load the codeword address into temporary
    sw t1, 0(t2)        # store the codeword address into HERE
    addi t2, t2, CELL   # prepare to move the HERE pointer by 1 CELL

    # move HERE pointer
    sw t2, 0(t0)        # store the new address of HERE into the HERE variable

    # update the STATE variable
    li t0, STATE        # load the address of the STATE variable into temporary
    sw zero, 0(t0)      # store the current state back into the STATE variable
    NEXT
