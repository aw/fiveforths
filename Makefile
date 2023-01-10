# fiveforths - https://github.com/aw/fiveforths
#
# Makefile for building and testing

PROGNAME = fiveforths
FIRMWARE ?= $(PROGNAME).bin
DEVICE ?= /dev/ttyUSB0
CFLAGS := -g
CROSS ?= /usr/bin/riscv64-unknown-elf-
AS := $(CROSS)as
LD := $(CROSS)ld
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
READELF := $(CROSS)readelf

# MCU and board specific variables
ARCH ?= rv32imac
EMU ?= elf32lriscv
MCU ?= gd32vf103
BOARD ?= longan-nano-lite

.PHONY: clean

build: $(PROGNAME).o $(PROGNAME).elf $(PROGNAME).bin $(PROGNAME).hex $(PROGNAME).dump

%.o: %.s
		$(AS) $(CFLAGS) -march=$(ARCH) -I src/boards/$(BOARD) -I src/mcus/$(MCU) -I src -o $@ $<

%.elf: %.o
		$(LD) -m $(EMU) -T src/boards/$(BOARD)/linker.ld -o $@ $<

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

flash:
		stm32loader -p $(DEVICE) -ewv $(FIRMWARE)

longan-nano:
		$(MAKE) build BOARD=longan-nano

longan-nano-lite:
		$(MAKE) build BOARD=longan-nano-lite

clean:
		rm -v *.bin *.elf *.o *.hex *.dump
