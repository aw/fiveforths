# fiveforths - https://github.com/aw/fiveforths
#
# Makefile for building and testing

PROGNAME = fiveforths
CFLAGS := -g
ARCH ?= rv32imac # rv32imac for Longan Nano
EMU ?= elf32lriscv
CROSS ?= /usr/bin/riscv64-unknown-elf-
AS := $(CROSS)as
LD := $(CROSS)ld
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
READELF := $(CROSS)readelf

.PHONY: clean

build: $(PROGNAME).o $(PROGNAME).elf $(PROGNAME).bin $(PROGNAME).hex $(PROGNAME).dump

%.o: %.s
		$(AS) $(CFLAGS) -march=$(ARCH) -o $@ $<

%.elf: %.o
		$(LD) -m $(EMU) -T $(PROGNAME).ld -o $@ $<

%.bin: %.elf
		$(OBJCOPY) -O binary $< $@

%.hex: %.elf
		$(OBJCOPY) -O ihex $< $@

%.dump: %.elf
		$(OBJDUMP) -D -S $< > $@

readelf: $(PROGNAME).elf
		$(READELF) -a $<

clean:
		rm -v *.bin *.elf *.o *.hex *.dump
