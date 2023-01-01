/*
FiveForths - https://github.com/aw/FiveForths
RISC-V Forth implementation

The MIT License (MIT)
Copyright (c) 2021 Alexander Williams, On-Prem <license@on-premises.com>
*/

.equ FORTH_VERSION, 1

##
# Memory map
##

# adjust these values for specific targets
.equ CELL, 4                            # 32-bits cell size
.equ RAM_BASE, 0x20000000               # base address of RAM
.equ RAM_SIZE, 1024 * 20                # 20 KiB
.equ STACK_SIZE, 256                    # 256 Bytes

# DSP, RSP, TIB stacks grow downward from the top of memory
.equ DSP_TOP, RAM_BASE + RAM_SIZE       # address of top of data stack
.equ RSP_TOP, DSP_TOP - STACK_SIZE      # address of top of return stack
.equ TIB_TOP, RSP_TOP - STACK_SIZE      # address of top of terminal buffer
.equ TIB, TIB_TOP - STACK_SIZE          # address of bottom of terminal buffer

# variables
.equ STATE, TIB - CELL                  # 1 CELL for STATE variable
.equ TOIN, STATE - CELL                 # 1 CELL for TOIN variable (looks into TIB)
.equ HERE, TOIN - CELL                  # 1 CELL for HERE variable
.equ LATEST, HERE - CELL                # 1 CELL for LATEST variable
.equ NOOP, LATEST - CELL                # 1 CELL for NOOP variable
.equ PAD, NOOP - (CELL * 64)            # 64 CELLS between NOOP and PAD

# dictionary grows upward from the RAM base address
.equ FORTH_SIZE, PAD - RAM_BASE         # remaining memory for Forth

##
# Interpreter constants
##

.equ CHAR_NEWLINE, '\n'         # newline character 0x0A
.equ CHAR_CARRIAGE, '\r'        # carriage return character 0x13
.equ CHAR_SPACE, ' '            # space character 0x20
.equ CHAR_BACKSPACE, '\b'       # backspace character 0x08
.equ CHAR_COMMENT, '\\'         # backslash character 0x5C
.equ CHAR_COMMENT_OPARENS, '('  # open parenthesis character 0x28
.equ CHAR_COMMENT_CPARENS, ')'  # close parenthesis character 0x29
.equ CHAR_MINUS, '-'            # minus character 0x2D

.equ F_IMMEDIATE, 0x80000000    # inverse = 0x7fffffff, immediate flag mask
.equ F_HIDDEN, 0x40000000       # inverse = 0xbfffffff, hidden flag mask
.equ F_USER, 0x20000000         # inverse = 0xdfffffff, user flag mask
.equ FLAGS_MASK, 0xe0000000     # inverse = 0x1fffffff, 3-bit flags mask
.equ FLAGS_LEN, 0xff000000      # inverse = 0x00ffffff, 8-bit flags+length mask

##
# Forth registers
##

# sp = DSP = data stack pointer
# a0 = W   = working register
# a1 = X   = working register
# a2 = Y   = working register
# a3 = Z   = working register
# s0 = FP  = frame pointer (unused for now)
# s1 = IP  = instruction pointer
# s2 = RSP = return stack pointer
# s3 = TOS = top of stack pointer (data stack)

##
# Macros
##

# jump to the next subroutine, appended to each primitive
.macro NEXT
    mv a0, s1           # load memory address from IP into W
    addi s1, s1, CELL   # increment IP by CELL size
    jr a0               # jump to the address in W
.endm

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

# push variable to top of stack
.macro PUSHVAR var
    addi sp, sp, -CELL  # move the DSP down by 1 cell
    sw s3, 0(sp)        # store the value in the TOS to the top of the DSP
    li t0, \var         # load variable into temporary
    lw s3, 0(t0)        # load variable address value into TOS
.endm

# push register to return stack
.macro PUSHRSP reg
    addi s2, s2, -CELL  # decrement RSP by 1 cell
    sw \reg, 0(s2)      # store value from register into RSP
.endm

# pop top of return stack to register
.macro POPRSP reg
    lw \reg, 0(s2)      # load value from RSP into register
    addi s2, s2, CELL   # increment RSP by 1 cell
.endm

# define a primitive dictionary word
.macro defcode name, hash, label, link
    .section .rodata
    .balign CELL        # align to CELL bytes boundary
    .globl word_\label
  word_\label :
    .4byte word_\link   # 32-bit pointer to codeword of link
    .4byte \hash        # 32-bit hash of this word
    .globl code_\label
  code_\label :
    .4byte body_\label  # 32-bit pointer to codeword of label
    .balign CELL        # align to CELL bytes boundary
    .text
    .balign CELL        # align to CELL bytes boundary
    .globl body_\label
  body_\label :         # assembly code below
.endm

# check a character
.macro checkchar char, dest
    call uart_get       # read a character from UART
    call uart_put       # send the character to UART

    # validate the character which is located in the W (a0) register
    li t0, \char        # load character into temporary
    beq a0, t0, \dest   # jump to the destination if the char matches
.endm

.text

##
# Interrupts
##

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

# include board-specific functions
.include "gd32vf103.s"

##
# I/O Helpers
##

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

##
# Forth
##

# compute a hash of a word
# arguments: a0 = buffer address, a1 = buffer size
# returns: a0 = 32-bit hash value
djb2_hash:
    li t0, 5381         # t0 = hash value
    li t1, 33           # t1 = multiplier
    mv t3, a1           # t3 = word length
    slli t3, t3, 24     # shift the length left by 24 bits
djb2_hash_loop:
    beqz a1, djb2_hash_done
    lbu t2, 0(a0)       # load 1 byte from a0 into t2
    mul t0, t0, t1      # multiply hash by 33
    add t0, t0, t2      # add character value to hash
    addi a0, a0, 1      # increase buffer address by 1
    addi a1, a1, -1     # decrease buffer size by 1
    j djb2_hash_loop    # repeat
djb2_hash_done:
    li t1, ~FLAGS_LEN   # load the inverted 8-bit flags+length mask into temporary
    and a0, t0, t1      # clear the top eight bits (used for flags and length)
    or a0, a0, t3       # add the length to the final hash value

    ret                 # a0 = final hash value

# obtain a word (token) from the terminal input buffer
# arguments: a0 = buffer start address (TIB), a1 = buffer current address (TOIN)
# returns: a0 = token buffer start address, a1 = token size (length in bytes)
token:
    li t1, CHAR_SPACE           # initialize temporary to 'space' character
    mv t2, zero                 # initialize temporary counter to 0
token_char:
    blt a1, a0, token_done      # compare the address of TOIN with the address of TIB
    lbu t0, 0(a1)               # read char from TOIN address
    addi a1, a1, -1             # move TOIN pointer down
    bgeu t1, t0, token_space    # compare char with space
    addi t2, t2, 1              # increment the token size for each non-space byte read
    j token_char                # loop to read the next character
token_space:
    beqz t2, token_char         # loop to read next character if token size is 0
    j token_done                # token reading is done
token_done:
    mv a1, t2                   # store the size in X

    ret

# convert a string token to a 32-bit integer
# arguments: a0 = token buffer start address, a1 = token size (length in bytes)
# returns: a0 = integer value, a1 = 1=OK, 0=ERROR
number:
    li t1, 10                   # initialize temporary to 10: multiplier
    mv t0, zero                 # initialize temporary to 0: holds the final integer
    li t3, CHAR_MINUS           # initialize temporary to minus character '-'
    mv t4, zero                 # initialize temporary to 0: sign flag of integer
    lbu t2, 0(a0)               # load first character from W working register
    bne t2, t3, number_digit    # jump to number digit loop if the first character is not a minus sign
    # first character is a minus sign, so the number will be negative
    li t4, 1                    # number is negative, store a 1 flag in temporary
    addi a0, a0, 1              # increment buffer address by 1 character
    addi a1, a1, -1             # decrease buffer size by 1
number_digit:
    # check if the character in the token is a digit between "0" (0x30) and "9" (0x39)
    # if we take the digit and subtract 0x30 and the result is < 0, then it's not a digit (error)
    # if we take the digit and subtract 0x30 and the result is > 9, then it's not a digit (error)
    # otherwise it's a digit (loop)
    beqz a1, number_done        # if the size of the buffer is 0 then we're done
    lbu t2, 0(a0)               # load next character into temporary
    addi t2, t2, -0x30          # subtract 0x30 from the character
    bgeu t2, t1, number_error   # check if character is < 0 or >= 10
    mul t0, t0, t1              # multiply previous number by 10 (base 10)
    add t0, t0, t2              # add previous number to current digit
    addi a0, a0, 1              # increment buffer address by 1 character
    addi a1, a1, -1             # decrease buffer size by 1
    j number_digit              # loop to check the next character
number_error:
    li a1, 0                    # number is too large or not an integer, return 0
    ret
number_done:
    beqz t4, number_store       # don't negate the number if it's positive
    neg t0, t0                  # negate the number using two's complement
number_store:
    mv a0, t0                   # copy final number to W working register
    li a1, 1                    # number is an integer, return 1
    ret

# search for a hash in the dictionary
# arguments: a0 = hash of the word, a1 = address of the LATEST word
# returns: a0 = hash of the word, a1 = address of the word if found
lookup:
    beqz a1, error              # error if the address is 0 (end of the dictionary)
    lw t0, 4(a1)                # load the hash of the word from the X working register

    # check if the word is hidden
    li t1, F_HIDDEN            # load the HIDDEN flag into temporary
    and t1, t0, t1             # read the hidden flag bit
    bnez t1, lookup_next       # skip the word if it's hidden

    # remove the 3-bit flags using a mask
    li t1, ~FLAGS_MASK         # load the inverted 3-bit flags mask into temporary
    and t0, t0, t1             # ignore flags when comparing the hashes
    beq t0, a0, lookup_done    # done if the hashes match
lookup_next:
    lw a1, 0(a1)               # follow link to next word in dict
    j lookup
lookup_done:
    ret

.text
.global _start

# board boot initializations
_start:
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

# reset the Forth stack pointers, registers, variables, and state
reset:
    # initialize stack pointers
    la sp, __stacktop           # initialize DSP register
    la s1, interpreter_start    # initialize IP register
    li s2, RSP_TOP              # initialize RSP register
    mv s3, zero                 # initialize TOS register

    # initialize function parameters
    mv a0, zero         # initialize W register
    mv a1, zero         # initialize X register
    mv a2, zero         # initialize Y register
    mv a3, zero         # initialize Z register

    # initialize STATE variable
    li t0, STATE        # load STATE variable
    sw zero, 0(t0)      # initialize STATE variable (0 = execute)

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

.balign CELL
# print an error message to the UART
error:
    li a0, CHAR_SPACE
    call uart_put
    li a0, '?'
    call uart_put
    li a0, CHAR_NEWLINE
    call uart_put

    j reset             # jump to reset the stack pointers, variables, etc before jumping to the interpreter

.balign CELL
# print an OK message to the UART
ok:
    li a0, CHAR_SPACE
    call uart_put
    li a0, 'o'
    call uart_put
    li a0, 'k'
    call uart_put
    li a0, CHAR_NEWLINE
    call uart_put

    j tib_init          # jump to reset the terminal input buffer before jumping to the interpreter

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
    la a2, docol        # load the codeword address into Y working register

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

.balign CELL

.section .rodata

# here's where the program starts (the interpreter)
interpreter_start:
    li t2, TIB                                  # load TIB memory address
    li t3, TOIN                                 # load the TOIN variable into unused temporary register
    lw a1, 0(t3)                                # load TOIN address value into X working register

interpreter:
    call uart_get                               # read a character from UART
    li t4, CHAR_NEWLINE                         # load newline into temporary
    beq a0, t4, skip_send                       # don't send the character if it's a newline
    call uart_put                               # send the character to UART

skip_send:
    # validate the character which is located in the W (a0) register
    li t0, CHAR_COMMENT                         # load comment character into temporary
    beq a0, t0, skip_comment                    # skip the comment if it matches

    li t0, CHAR_COMMENT_OPARENS                 # load opening parens into temporary
    beq a0, t0, skip_oparens                    # skip the opening parens if it matches

    li t0, CHAR_BACKSPACE                       # load backspace into temporary
    beq a0, t0, process_backspace               # process the backspace if it matches

    li t0, CHAR_CARRIAGE                        # load carriage return into temporary
    beq a0, t0, process_carriage                # process the carriage return if it matches

    # TODO: check if character is printable

interpreter_tib:
    # add the character to the TIB
    li t4, TIB_TOP                              # load TIB_TOP memory address
    bge a1, t4, error                           # error if the terminal input buffer is full # FIXME: handle this better
    sb a0, 0(a1)                                # store the character from W register in the TIB
    addi a1, a1, 1                              # increment TOIN value by 1
    li t0, CHAR_NEWLINE                         # load newline into temporary
    beq a0, t0, process_token                   # process the token if it matches

    j interpreter                               # return to the interpreter if it's not a newline

skip_comment:
    checkchar CHAR_NEWLINE, interpreter         # check if character is a newline
    j skip_comment                              # loop until it's a newline

skip_oparens:
    checkchar CHAR_COMMENT_CPARENS, interpreter # check if character is a closing parens
    j skip_oparens                              # loop until it's a closing parens

process_backspace:
    # erase the previous character on screen by sending a space then backspace character
    li a0, ' '
    call uart_put
    li a0, '\b'
    call uart_put

    # erase a character from the terminal input buffer (TIB) if there is one
    beq a1, t2, interpreter # return to interpreter if TOIN == TIB
    addi a1, a1, -1         # decrement TOIN by 1 to erase a character
    sw a1, 0(t3)            # store new TOIN value in memory

    j interpreter           # return to the interpreter after erasing the character

process_carriage:
    li a0, CHAR_NEWLINE     # convert a carriage return to a newline
    j interpreter_tib       # jump to add the character to the TIB

.balign CELL
process_token:
    li a0, CHAR_SPACE       # convert newline to a space
    sb a0, -1(a1)           # replace previous newline character with space in W register

    # process the token
    mv a0, t2               # load the TIB address in the W working register
    call token              # read the token

    # move TOIN
    lw t0, 0(t3)            # load TOIN address value into temporary
    add t0, t0, a1          # add the size of the token to TOIN
    sw t0, 0(t3)            # move TOIN to process the next word in the TIB

    # bounds checks on token size
    beqz a1, ok             # ok if token size is 0
    li t0, 32               # load max token size  (2^5 = 32) in temporary
    bgtu a1, t0, error      # error if token size is greater than 32

    call djb2_hash          # hash the token

    li a1, LATEST           # load LATEST variable into temporary
    lw a1, 0(a1)            # load LATEST value into temporary
    call lookup             # lookup the hash in the dictionary

    # check if the word is immediate
    lw t0, CELL(a1)         # load the hash of the found word into temporary
    li t1, F_IMMEDIATE      # load the IMMEDIATE flag into temporary
    and t0, t0, t1          # read the status of the immediate flag bit

    # load the STATE variable value
    li t1, STATE            # load the address of the STATE variable into temporary
    lw t1, 0(t1)            # load the current state into a temporary

    # decide if we want to execute or compile the word
    or t0, t0, t1           # logical OR the immediate flag and state
    addi t0, t0, -1         # decrement the result by 1
    beqz t0, compile        # compile the word if the result is 0

.balign CELL
execute:
    la s1, ok               # load the address of the interpreter into the IP register
    addi a0, a1, 2*CELL     # increment the address of the found word by 8 to get the codeword address
    lw t0, 0(a0)            # load memory address from W into temporary
execute_done:
    jr t0                   # jump to the address in temporary

.balign CELL
compile:
compile_done:
    j ok
