MEMORY {
  RAM   (wx) : ORIGIN = 0x0, LENGTH = 16M
}

OUTPUT_FORMAT("elf32-littleriscv", "elf32-littleriscv", "elf32-littleriscv")
OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
  .text : {
    KEEP(*(.vectors))
    *(.text*)
    . = ALIGN(16);
  } > RAM

  .rodata : {
    *(.rodata*)
    *(.srodata*)
    . = ALIGN(16);
  } > RAM

  .data : {
    *(.data*)
    *(.sdata*)
    . = ALIGN(16);
  } > RAM
  /* For newlib: */
  PROVIDE(_edata = .);

  .bss : {
    *(.bss .bss.*)
    PROVIDE(__global_pointer$ = .);
    *(.sbss*)
    . = ALIGN(16);
  } > RAM
  PROVIDE(__bss_end = .);
  /* For newlib: */
  PROVIDE(_end = .);

  .testdata BLOCK(1M) :
  {
    PROVIDE(__testdata_start = .);
   *(.testdata)
    . = ALIGN(4);
    PROVIDE(__testdata_end = .);
  } > RAM

  PROVIDE(__stacktop = ORIGIN(RAM) + LENGTH(RAM));

}


