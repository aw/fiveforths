/*
FiveForths - https://github.com/aw/FiveForths
RISC-V Forth implementation

The MIT License (MIT)
Copyright (c) 2021 Alexander Williams, On-Prem <license@on-premises.com>
*/

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

.include "01-variables-constants.s"
.include "02-macros.s"
.include "03-interrupts.s"

# include board-specific functions
.include "gd32vf103.s"

.include "04-io-helpers.s"
.include "05-internal-functions.s"
.include "06-initialization.s"
.include "07-error-handling.s"
.include "08-forth-primitives.s"
.include "09-interpreter.s"
