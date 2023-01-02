##
# Macros
##

# jump to the next subroutine, appended to each primitive
.macro NEXT
    lw a0, 0(s1)        # load memory address from IP into W
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
