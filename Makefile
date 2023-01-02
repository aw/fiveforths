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
		$(AS) $(CFLAGS) -march=$(ARCH) -I src -o $@ $<

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

serve:
		bundle exec jekyll serve

openocd:
		/opt/riscv/bin/openocd -f ft232r.cfg -f openocd.cfg

debug:
		/opt/riscv/bin/riscv64-unknown-elf-gdb -command=debug.gdb -q fiveforths.elf

clean:
		rm -v *.bin *.elf *.o *.hex *.dump
