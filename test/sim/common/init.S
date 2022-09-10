.section .vectors, "ax"

#define IO_BASE 0x80000000
#define IO_EXIT       (IO_BASE + 0x8)

// ----------------------------------------------------------------------------
// General purpose registers

// 32x 32-bit registers, in RAM. The testbench is configured to put these at
// address zero. (Note space must still be allocated for x0, even if the
// implementation never writes to it or reads it.)

.global __registers
__registers:
.rept 32
.word 0
.endr

// ----------------------------------------------------------------------------
// Reset handler

// The testbench configures the processor to enter directly after the GPRs.

.global __reset_vector
__reset_vector:
.option push
.option norelax
	la gp, __global_pointer$
.option pop
	la sp, __stacktop
	jal _really_start // FIXME
	j _exit

// ----------------------------------------------------------------------------
// "Runtime"

.section .text

.global _exit
_exit:
	li a1, IO_EXIT
	sw a0, (a1)

.global _sbrk
_sbrk:
	la a1, heap_ptr
	lw a2, (a1)
	add a0, a0, a2
	sw a0, (a1)
	mv a0, a2
	ret

.section .data

.p2align 2
heap_ptr:
	.word __bss_end

// FIXME REMOVE:

.section .text

_really_start:
	li a0, 123
	j _exit
