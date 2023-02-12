: invert -1 nand ;
: over sp@ 4 + @ ;
: swap over over sp@ 12 + ! sp@ 4 + ! ;
: and nand invert ;
: or invert swap invert nand ;
: green_led_on 0x40010800 @ 0xFFFFFF0F and 0x00000030 or 0x40010800 ! ;
: blue_led_on 0x40010800 @ 0xFFFFF0FF and 0x00000300 or 0x40010800 ! ;
: green_led_off 0x40010800 @ 0xFFFFFF0F and 0x00000040 or 0x40010800 ! ;
: blue_led_off 0x40010800 @ 0xFFFFF0FF and 0x00000400 or 0x40010800 ! ;
