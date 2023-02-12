.text
.global _start
_start:
	call _setup
	call djb2_hash
	ret

.include "board.s"
.include "mcu.s"
.include "01-variables-constants.s"
.include "02-macros.s"
.include "03-interrupts.s"
.include "04-io-helpers.s"
.include "05-internal-functions.s"
.include "06-initialization.s"
.include "07-error-handling.s"
.include "08-forth-primitives.s"
.include "09-interpreter.s"

_setup:
    li a0, 0x20004d00
    li a1, 32
    # store 32 byte word in memory
    li t1, 0x61626364
    sw t1, 0(a0)
    li t1, 0x65666768
    sw t1, 4(a0)
    li t1, 0x696a6b6c
    sw t1, 8(a0)
    li t1, 0x6d6e6f70
    sw t1, 12(a0)
    li t1, 0x61626364
    sw t1, 16(a0)
    li t1, 0x65666768
    sw t1, 20(a0)
    li t1, 0x696a6b6c
    sw t1, 24(a0)
    li t1, 0x6d6e6f70
    sw t1, 28(a0)
    ret
