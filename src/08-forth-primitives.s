##
# Forth primitives
##

.equ word_NULL, 0

# @ ( addr -- x )       Fetch memory at addr
defcode "@", 0x0102b5e5, FETCH, NULL
    lw s3, 0(s3)        # load address value from TOS (addr) into TOS (x)
    NEXT

# ! ( x addr -- )       Store x at addr
defcode "!", 0x0102b5c6, STORE, FETCH
    lw t0, 0(sp)        # load the DSP value (x) into temporary
    sw t0, 0(s3)        # store temporary into address stored in TOS (addr)
    lw s3, CELL(sp)     # load second value in DSP to TOS
    addi sp, sp, 2*CELL # move DSP up by 2 cells
    NEXT

# sp@ ( -- addr )       Get current data stack pointer
defcode "sp@", 0x0388aac8, DSPFETCH, STORE
    PUSH sp             # store DSP in TOS
    NEXT

# rp@ ( -- addr )       Get current return stack pointer
defcode "rp@", 0x0388a687, RSPFETCH, DSPFETCH
    PUSH s2             # store RSP in TOS
    NEXT

# 0= ( x -- f )         -1 if top of stack is 0, 0 otherwise
defcode "0=", 0x025970b2, ZEQU, RSPFETCH
    seqz s3, s3         # store 1 in TOS if TOS is equal to 0, otherwise store 0
    NEXT

# + ( x1 x2 -- n )      Add the two values at the top of the stack
defcode "+", 0x0102b5d0, ADD, ZEQU
    POP t0              # pop value into temporary
    add s3, s3, t0      # add values and store in TOS
    NEXT

# nand ( x1 x2 -- n )   Bitwise NAND the two values at the top of the stack
defcode "nand", 0x049b0c66, NAND, ADD
    POP t0              # pop value into temporary
    and s3, s3, t0      # store bitwise AND of temporary and TOS into TOS
    not s3, s3          # store bitwise NOT of TOS into TOS
    NEXT

# exit ( r:addr -- )    Resume execution at address at the top of the return stack
defcode "exit", 0x04967e3f, EXIT, NAND
    POPRSP s1           # pop RSP into IP
    NEXT

##
# Forth I/O
##

# key ( -- x )          Read 8-bit character from uart input
defcode "key", 0x0388878e, KEY, EXIT
    call uart_get       # read character from uart into W
    PUSH a0             # store character into TOS
    NEXT

# emit ( x -- )         Write 8-bit character to uart output
defcode "emit", 0x04964f74, EMIT, KEY
    POP a0              # copy TOS into W
    call uart_put       # send character from W to uart
    NEXT

##
# Forth variables
##

defcode "tib", 0x0388ae44, TIB, EMIT
    PUSHVAR TIB         # store TIB variable value in TOS
    NEXT

defcode "state", 0x05614a06, STATE, TIB
    PUSHVAR STATE       # store STATE variable value in TOS
    NEXT

defcode ">in", 0x0387c89a, TOIN, STATE
    PUSHVAR TOIN        # store TOIN variable value in TOS
    NEXT

defcode "here", 0x0497d3a9, HERE, TOIN
    PUSHVAR HERE        # store HERE variable value in TOS
    NEXT

defcode "latest", 0x06e8ca72, LATEST, HERE
    PUSHVAR LATEST      # store LATEST variable value in TOS
    NEXT

##
# Forth words
##

# : ( -- )              # Start the definition of a new word
defcode ":", 0x0102b5df, COLON, LATEST
    li a0, TIB          # load TIB into W
    li t3, TOIN         # load the TOIN variable into unused temporary register
    lw a1, 0(t3)        # load TOIN address value into X working register
    call token          # read the token

    # bounds checks on token size
    beqz a1, error      # error if token size is 0
    li t0, 32           # load max token size  (2^5 = 32) in temporary
    bgtu a1, t0, error  # error if token size is greater than 32

    # store the word then hash it
    sw a0, 0(t3)        # store new address into TOIN variable
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
    li t5, PAD          # load out of bounds memory address (PAD)
    bgt t4, t5, error   # error if the memory address is out of bounds

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
    addi s1, a2, CELL   # skip code field in Y by adding a CELL, store it in IP
    NEXT

.addr: .word docol      # indirect jump to docol from a colon definition

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
    la t1, code_EXIT    # load the codeword address into temporary # FIXME: why not body_EXIT?
    sw t1, 0(t0)        # store the codeword address into HERE

    # bounds check on the exit memory location
    addi t2, t2, CELL   # prepare to move the HERE pointer by 1 CELL
    li t3, PAD          # load out of bounds memory address (PAD)
    bgt t2, t3, error   # error if the memory address is out of bounds

    # move HERE pointer
    sw t2, 0(t0)        # store the new address of HERE into the HERE variable

    # update the STATE variable
    li t0, STATE        # load the address of the STATE variable into temporary
    sw zero, 0(t0)      # store the current state back into the STATE variable
    NEXT
