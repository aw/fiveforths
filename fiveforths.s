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

# variables
.equ TIB, TIB_TOP - STACK_SIZE          # 1 CELL for TIB variable
.equ STATE, TIB - CELL                  # 1 CELL for STATE variable
.equ TOIN, STATE - CELL                 # 1 CELL for TOIN variable
.equ HERE, TOIN - CELL                  # 1 CELL for HERE variable
.equ LATEST, HERE - CELL                # 1 CELL for LATEST variable
.equ NOOP, LATEST - CELL                # 1 CELL for NOOP variable
.equ INDEXES, NOOP - (CELL * 64)        # 64 CELLS between NOOP and INDEXES
.equ PAD, INDEXES - (CELL * 64)         # 64 CELLS between INDEXES and PAD

# dictionary grows upward from the RAM base address
.equ FORTH_SIZE, PAD - RAM_BASE         # remaining memory for Forth

##
# Forth registers
##

# sp = DSP = data stack pointer
# a0 = W   = working register
# s0 = FP  = frame pointer (unused for now)
# s1 = IP  = instruction pointer
# s2 = RSP = return stack pointer
# s3 = TOS = top of stack pointer (data stack)
# s4 = SOS = second to top of stack pointer (data stack)

##
# Macros to boost performance
##

# jump to the next subroutine, appended to each primitive
.macro NEXT
    lw a0, 0(s1)        # load memory address from IP into W
    addi s1, s1, CELL   # increment IP by CELL size
    lw t0, 0(a0)        # load memory address from W into temporary
    jr t0               # jump to the address in temporary
.endm

# push register to data stack
.macro PUSH reg
    addi sp, sp, -4     # decrement DSP by 4 bytes (32-bit aligned)
    sw \reg, 0(sp)      # store value from register into DSP
.endm

# pop top of data stack to register
.macro POP reg
    lw \reg, 0(sp)      # load value from DSP into register
    addi sp, sp, 4      # increment DSP by 4 bytes (32-bit aligned)
.endm

# pop first and second top of stack data registers into reg1 and reg2
# example: DUALPOP s3, s4
.macro DUALPOP reg1, reg2
    lw \reg1, 0(sp)     # load first stack element from DSP into register 1
    lw \reg2, 4(sp)     # load second stack element from DSP into register 2
    addi sp, sp, 8      # increment DSP by 2 cells (32-bit aligned)
.endm

# push register to return stack
.macro PUSHRSP reg
    addi s2, s2, -4     # decrement RSP by 4 bytes (32-bit aligned)
    sw \reg, 0(s2)      # store value from register into RSP
.endm

# pop top of return stack to register
.macro POPRSP reg
    lw \reg, 0(s2)      # load value from RSP into register
    addi s2, s2, 4      # increment RSP by 4 bytes (32-bit aligned)
.endm

# TODO: describe what this does
.macro RCALL symbol
    PUSH ra             # push ra (return address) on to stack
    call \symbol        # call the function
    POP ra              # fetch ra from the stack
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

##
# Forth instructions
##

.text

docol:
    PUSHRSP s1          # push IP onto the return stack
    addi s1, a0, CELL   # skip code field in W by adding a CELL, store it in IP
    NEXT

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
    li t1, 0x00ffffff   # load the bit mask ~0xFF000000
    and a0, t0, t1      # clear the top eight bits (used for flags and length)
    or a0, a0, t3       # add the length to the final hash value
    ret                 # a0 = final hash value

.text
.global _start

_start:
    la sp, __stacktop
    ret

# TODO: fixme
enter:
    sw s1, 0(s2)        # store memory address from IP into RSP
    addi s2, s2, CELL   # increment RSP by CELL size
    addi s1, a0, CELL   # increment IP by W + CELL size
    NEXT

##
# Forth primitives
##

# FIXME: where are these used?
.equ F_IMMED, 0x80000000 # 0x7fffffff
.equ F_HIDDEN, 0x40000000 # 0xbfffffff

.equ word_NULL, 0

# OK
defcode "@", 0x0102b5e5, FETCH, NULL
    lw s3, 0(s3)        # load address value from TOS into TOS
    NEXT

# OK
defcode "!", 0x0102b5c6, STORE, FETCH
    sw s4, 0(s3)        # store value from SOS into memory address stored in TOS
    DUALPOP s3, s4      # pop first and second top of stack data registers into TOS and SOS
    NEXT

# OK
defcode "sp@", 0x0388aac8, DSPFETCH, STORE
    mv t0, sp           # copy DSP into temporary
    PUSH s3             # push TOS to top of data stack
    mv s3, t0           # copy temporary to TOS
    NEXT

# OK
defcode "rp@", 0x0388a687, RSPFETCH, DSPFETCH
    PUSH s3             # push TOS to top of data stack
    mv s3, s2           # copy RSP to TOS
    NEXT

# OK
defcode "0=", 0x025970b2, ZEQU, RSPFETCH
    seqz s3, s3         # store 1 in TOS if TOS is equal to 0, otherwise store 0
    NEXT

# OK
defcode "+", 0x0102b5d0, ADD, ZEQU
    POP a0              # pop value into W
    add s3, a0, s3      # add TOS and W into TOS
    NEXT

# OK
defcode "nand", 0x049b0c66, NAND, ADD
    POP a0              # pop value into W
    and s3, s3, a0      # store bitwise AND of W and TOS into TOS
    not s3, s3          # store bitwise NOT of TOS into TOS
    NEXT

# OK
defcode "exit", 0x04967e3f, EXIT, NAND
    POPRSP s1           # pop RSP into IP
    NEXT

##
# Forth I/O
##

# FIXME
defcode "key", 0x0388878e, KEY, EXIT
    NEXT

# FIXME
defcode "emit", 0x04964f74, EMIT, KEY
    NEXT

##
# Forth variables
##

# OK
defcode "tib", 0x0388ae44, TIB, EMIT
    PUSH s3             # push TOS to top of data stack
    li t0, TIB          # load address value from TIB into temporary
    lw s3, 0(t0)        # load temporary into TOS
    NEXT

# OK
defcode "state", 0x05614a06, STATE, TIB
    PUSH s3             # push TOS to top of data stack
    li t0, STATE        # load address value from STATE into temporary
    lw s3, 0(t0)        # load temporary into TOS
    NEXT

# OK
defcode ">in", 0x0387c89a, TOIN, STATE
    PUSH s3             # push TOS to top of data stack
    li t0, TOIN         # load address value from TOIN into temporary
    lw s3, 0(t0)        # load temporary into TOS
    NEXT

# OK
defcode "here", 0x0497d3a9, HERE, TOIN
    PUSH s3             # push TOS to top of data stack
    li t0, HERE         # load address value from HERE into temporary
    lw s3, 0(t0)        # load temporary into TOS
    NEXT

# OK
defcode "latest", 0x06e8ca72, LATEST, HERE
    PUSH s3             # push TOS to top of data stack
    li t0, LATEST       # load address value from LATEST into temporary
    lw s3, 0(t0)        # load temporary into TOS
    NEXT

##
# Forth words
##

# FIXME
defcode ":", 0x0102b5df, COLON, LATEST
    NEXT

# FIXME
defcode ";", 0x0102b5e0, SEMI, COLON
    NEXT

.balign CELL

# add a few strings which will be used in the program
.section .rodata

msgok:
    .ascii " ok\n"
msgerr:
    .ascii "  ?\n"
msgredef:
    .ascii " redefined ok\n"

.balign CELL            # align to CELL bytes boundary

.text

here:                   # next new word will go here
ret
