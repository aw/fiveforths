##
# Macros
##

# jump to the next subroutine (ITC), appended to each primitive
.macro NEXT
    lw a0, 0(s1)        # load memory address from IP into W
    addi s1, s1, CELL   # increment IP by CELL size
    lw t0, 0(a0)        # load address from W into temporary
    jr t0               # jump to the address in temporary
.endm

# pop top of data stack to register and move DSP
.macro POP reg
    lw \reg, 0(sp)      # load DSP value to register
    addi sp, sp, CELL   # move the DSP up by 1 cell
.endm

# push register to top of stack and move DSP
.macro PUSH reg
    li t0, RSP_TOP+CELL         # load address of bottom of stack + 1 CELL
    blt sp, t0, err_overflow    # jump to error handler if stack overflow

    sw \reg, -CELL(sp)  # store the value in the register to the top of the DSP
    addi sp, sp, -CELL  # move the DSP down by 1 cell
.endm

# push variable to top of stack
.macro PUSHVAR var
    li t0, RSP_TOP+CELL         # load address of bottom of stack + 1 CELL
    blt sp, t0, err_overflow    # jump to error handler if stack overflow

    li t0, \var         # load variable into temporary
    sw t0, -CELL(sp)    # store the variable value to the top of the DSP
    addi sp, sp, -CELL  # move the DSP down by 1 cell
.endm

# push register to return stack
.macro PUSHRSP reg
    li t0, TIB_TOP+CELL         # load address of bottom of stack + 1 CELL
    blt s2, t0, err_overflow    # jump to error handler if stack overflow

    sw \reg, -CELL(s2)  # store value from register into RSP
    addi s2, s2, -CELL  # decrement RSP by 1 cell
.endm

# pop top of return stack to register
.macro POPRSP reg
    li t0, RSP_TOP              # load address of top of RSP
    bge s2, t0, err_underflow   # jump to error handler if stack underflow

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
    .globl hash_\label
  hash_\label :
    .4byte \hash        # 32-bit hash of this word
    .globl code_\label
  code_\label :
    .4byte body_\label  # 32-bit pointer to codeword of label
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

# print a message
.macro print_error name, size, jump
    .balign CELL
  err_\name :
    la a1, msg_\name    # load string message
    addi a2, a1, \size  # load string length
    call uart_print     # call uart print function
    j \jump             # jump when print returns
.endm

# restore HERE and LATEST variables
.macro restorevars reg
    # update HERE
    li t0, HERE         # load HERE variable into temporary
    sw \reg, 0(t0)      # store the address of LATEST back into HERE

    # update LATEST
    li t0, LATEST       # load LATEST variable into temporary
    lw t1, 0(\reg)      # load LATEST variable value into temporary
    sw t1, 0(t0)        # store LATEST word into LATEST variable
.endm

# check for stack underflow
.macro checkunderflow stacktop
    li t0, DSP_TOP-\stacktop    # load address of top of stack
    bge sp, t0, err_underflow   # jump to error handler if stack underflow
.endm
