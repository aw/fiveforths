/*
FiveForths - https://github.com/aw/FiveForths
RISC-V Forth implementation

The MIT License (MIT)
Copyright (c) 2021 Alexander Williams, On-Prem <license@on-premises.com>
*/

.set FORTH_VERSION, 1

##
# Memory map
##

# adjust these values for specific targets
.equ CELL, 4                            # 32-bits cell size
.equ RAM_BASE, 0x20000000               # base address of RAM
.equ RAM_SIZE, 1024 * 20                # 20 KiB
.equ STACK_SIZE, 1024                   # 1 KiB

# DSP, RSP, TIB stacks grow downward from the top of memory
.equ DSP_TOP, RAM_BASE + RAM_SIZE       # address of top of data stack
.equ RSP_TOP, DSP_TOP - STACK_SIZE      # address of top of return stack
.equ TIB_TOP, RSP_TOP - STACK_SIZE      # address of top of terminal buffer
.equ TIB, TIB_TOP - STACK_SIZE          # address of bottom of terminal buffer

# reserve 3x 1 KiB for stacks
.bss
.balign STACK_SIZE
data_stack:
    .space STACK_SIZE                   # reserve 1 KiB for data stack
return_stack:
    .space STACK_SIZE                   # reserve 1 KiB for return stack
tib_stack:
    .space STACK_SIZE                   # reserve 1 KiB for terminal buffer

# reserve 16 bytes (32-bit) or 32 bytes (64-bit) for variables
.balign (CELL * 4)
.equ STATE, TIB - CELL                  # 1 CELL for STATE variable
.equ HERE, STATE - CELL                 # 1 CELL for HERE variable
.equ LATEST, HERE - CELL                # 1 CELL for LATEST variable
.equ NOOP, LATEST - CELL                # 1 CELL for NOOP variable
variables:
    .space (CELL * 4)                   # reserve 4 CELLS zero-filled

# reserve 256 bytes (32-bit) or 512 bytes (64-bit) for hash indexes
.balign (CELL * 64)
.equ PAD, NOOP - (CELL * 64)            # 64 CELLS between NOOP and PAD
indexes:
    .space (CELL * 64)                  # reserve 64 CELLS zero-filled

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
# s3 = TOS = top of stack pointer
# s4 = TIB = terminal input buffer

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
    addi sp, sp, -16    # decrement DSP by 16 bytes (128-bit aligned)
    sw \reg, 0(sp)      # store value from register into DSP
.endm

# pop top of data stack to register
.macro POP reg
    lw \reg, 0(sp)      # load value from DSP into register
    addi sp, sp, 16     # increment DSP by 16 bytes (128-bit aligned)
.endm

# FIXME: does RSP also need to be 128-bit aligned?
# push register to return stack
.macro PUSHRSP reg
    addi s2, s2, -16    # decrement RSP by 16 bytes (128-bit aligned)
    sw \reg, 0(s2)      # store value from register into RSP
.endm

# pop top of return stack to register
.macro POPRSP reg
    lw \reg, 0(s2)      # load value from RSP into register
    addi s2, s2, 16     # increment RSP by 16 bytes (128-bit aligned)
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

.set F_IMMED, 0x80000000 # 0x7fffffff
.set F_HIDDEN, 0x40000000 # 0xbfffffff
.set word_NULL, 0

# OK
defcode "exit", 0x04967e3f, EXIT, NULL
    POPRSP s1           # pop RSP into IP
    NEXT

# FIXME
defcode ":", 0x0102b5df, COLON, NULL
    NEXT

# FIXME
defcode ";", 0x0102b5e0, SEMI, COLON
    NEXT

# OK
defcode "@", 0x0102b5e5, FETCH, SEMI
    lw s3, 0(s3)        # load address value from TOS into TOS
    NEXT

# OK
defcode "!", 0x0102b5c6, STORE, FETCH
    POP a0              # pop value into W
    sw a0, 0(s3)        # store value from W into memory address stored in TOS
    NEXT

# OK
defcode "sp@", 0x0388aac8, DSPFETCH, NULL
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
defcode "0=", 0x025970b2, ZEQU, NULL
    seqz s3, s3         # store 1 in TOS if TOS is equal to 0, otherwise store 0
    NEXT

# OK
defcode "+", 0x0102b5d0, ADD, STORE
    POP a0              # pop value into W
    add s3, a0, s3      # add TOS and W into TOS
    NEXT

# OK
defcode "nand", 0x049b0c66, NAND, EXIT
    POP a0              # pop value into W
    and s3, s3, a0      # store bitwise AND of W and TOS into TOS
    not s3, s3          # store bitwise NOT of TOS into TOS
    NEXT

# OK
defcode "state", 0x05614a06, STATE, NULL
    PUSH s3             # push TOS to top of data stack
    li t0, STATE        # load address value from STATE into temporary
    lw s3, 0(t0)        # load temporary into TOS
    NEXT

# OK
defcode "tib", 0x0388ae44, TIB, RSPFETCH
    PUSH s3             # push TOS to top of data stack
    li t0, TIB          # load address value from TIB into temporary
    lw s3, 0(t0)        # load temporary into TOS
    NEXT

# FIXME
defcode ">in", 0x0387c89a, TOIN, TIB
  NEXT

# OK
defcode "here", 0x0497d3a9, HERE, NAND
    PUSH s3             # push TOS to top of data stack
    li t0, HERE         # load address value from HERE into temporary
    lw s3, 0(t0)        # load temporary into TOS
    NEXT

# OK
defcode "latest", 0x06e8ca72, LATEST, NULL
    PUSH s3             # push TOS to top of data stack
    li t0, LATEST       # load address value from LATEST into temporary
    lw s3, 0(t0)        # load temporary into TOS
    NEXT

# FIXME
defcode "key", 0x0388878e, KEY, TOIN
    NEXT

# FIXME
defcode "emit", 0x04964f74, EMIT, HERE
    NEXT

.balign CELL            # align to CELL bytes boundary
here:                   # next new word will go here

.data
    # add a few strings which will be used in the program
    .balign CELL
    .ascii " ok\n"
    .ascii "  ?\n"
    .ascii " redefined ok\n"
    .balign CELL
    ret
