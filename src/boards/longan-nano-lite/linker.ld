/* GD32VF103C8 */
MEMORY
{
    FLASH (rx)      : ORIGIN = 0x08000000, LENGTH = 64k
    RAM (xrw)       : ORIGIN = 0x20000000, LENGTH = 20k
}

/* The entry point is the reset handler */
ENTRY(_start);

SECTIONS {
    __stacktop = ORIGIN(RAM) + LENGTH(RAM);

    /* The program code and other data goes into FLASH */
    .text :
    {
        . = ALIGN(4);
        *(.text)           /* .text sections (code) */
        *(.rodata)         /* .rodata sections (constants, strings, etc.) */
    } >FLASH

}
