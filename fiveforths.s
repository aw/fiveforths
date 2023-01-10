/*
FiveForths - https://github.com/aw/FiveForths
RISC-V Forth implementation

The MIT License (MIT)
Copyright (c) 2021~ Alexander Williams, https://a1w.ca
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

# Ensure the _start entry label is defined first
.text
.global _start
_start:
    j boot

# include board-specific functions and constants from src/boards/<board>/
.include "board.s"

# include MCU-specific functions and constants from src/mcus/<MCU>/
.include "mcu.s"

# include source files from src/
.include "01-variables-constants.s"
.include "02-macros.s"
.include "03-interrupts.s"
.include "04-io-helpers.s"
.include "05-internal-functions.s"
.include "06-initialization.s"
.include "07-error-handling.s"
.include "08-forth-primitives.s"
.include "09-interpreter.s"
