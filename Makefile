# fiveforths - https://github.com/aw/fiveforths
#
# Makefile for building and testing

CFLAGS := -g
ARCH ?= rv32imac # rv32imac for Longan Nano
EMU ?= elf32lriscv
CROSS ?= /usr/bin/riscv64-unknown-elf-
AS := $(CROSS)as
LD := $(CROSS)ld
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
READELF := $(CROSS)readelf

.PHONY: clean dump ldump

build: fiveforths.o fiveforths.elf fiveforths.bin fiveforths.hex

fiveforths.o: fiveforths.s
		$(AS) $(CFLAGS) -march=$(ARCH) -o $@ $<

fiveforths.elf:
		$(LD) -m $(EMU) -o $@ fiveforths.o

fiveforths.bin:
		$(OBJCOPY) -O binary fiveforths.elf $@

fiveforths.hex:
		$(OBJCOPY) -O ihex fiveforths.elf $@

dump:
		$(OBJDUMP) -D -S fiveforths.elf

readelf:
		$(READELF) -a fiveforths.elf

clean:
		rm -v *.bin *.elf *.o *.hex
