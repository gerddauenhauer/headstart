/* demo kernel: verify basic functions of a multiboot compliant boot loader.
 * (c) 2022, gerd dauenhauer
 * SPDX 0BSD, see the enclosed LICENSE file
 *
 * this file provides support code and parts of the c library.
 * the initial entry point is executed by the bootloader,
 * sets up some stack space and enters the c world. */

#define ASM_FILE
#include <multiboot.h>

	.section .multiboot
	.code32

	jmp	start



	.align	4
multiboot_header:
	.long	MULTIBOOT_HEADER_MAGIC
	.long	MULTIBOOT_MEMORY_INFO
	.long	-(MULTIBOOT_HEADER_MAGIC + MULTIBOOT_MEMORY_INFO)

	.long	multiboot_header
	.long	__text_begin
	.long	__data_end
	.long	__bss_end
	.long	start



	.section .data

gdt_begin:
gdt_null:
	.quad	0

gdt_code:
	.word	0xffff
	.word	0

	.byte	0
	.byte	0b10011010
	.byte	0b11001111
	.byte	0

gdt_data:
	.word	0xffff
	.word	0

	.byte	0
	.byte	0b10010010
	.byte	0b11001111
	.byte	0

gdt_stack:
	.word	0xffff
	.word	0

	.byte	0
	.byte	0b10010010
	.byte	0b11001111
	.byte	0

gdt_end:
gdt_list:
	.word	gdt_end - gdt_begin
	.long	gdt_begin



	.global	multiboot_info
multiboot_info:
	.long	0



	.section .text
	.code32

start:
	cmpl	$MULTIBOOT_BOOTLOADER_MAGIC, %eax
	jne	wrong_bootloader_panic

	movl	%ebx, multiboot_info

	cli
	lgdt	gdt_list

	jmp	$(gdt_code - gdt_begin), $load_cs



	.global	__kernel_stack_begin
	.global	__kernel_stack_end
	.global	main
load_cs:
	# intialize the other segment registers.
	movl	$(gdt_data - gdt_begin), %eax
	movl	%eax, %ds
	movl	%eax, %es
	movl	%eax, %fs
	movl	%eax, %gs


	# set up the kernel stack.
	movl	$(gdt_stack - gdt_begin), %eax
	movl	%eax, %ss

	movl	$__kernel_stack_end, %esp
	movl	%esp, %ebp


	# switch to c world.
	movl	$main, %eax
	call	*%eax

halt:
	jmp	halt



wrong_bootloader_panic:
_wrong_bootloader_panic_halt:
	hlt
	jmp	_wrong_bootloader_panic_halt



	# void cursor_get_position(unsigned *row, unsigned *column)
	.global	cursor_get_position
cursor_get_position:

	xorl	%eax, %eax
	xorl	%edx, %edx

	# get the position.
	movw	$0x03d4, %dx
	movb	$0x0e, %al
	outb	%al, %dx

	incw	%dx
	inb	%dx, %al
	movb	%al, %ah

	decw	%dx
	movb	$0x0f, %al
	outb	%al, %dx

	incw	%dx
	inb	%dx, %al

	# translate the position to coordinates.
	xorw	%dx, %dx		# position now is row * 80 + column
	movw	$80, %cx		# divide with rest to get row and column
	divw	%cx

	movl	4(%esp), %ecx
	movl	%eax, (%ecx)		# row pointer (division result)

	movl	8(%esp), %ecx
	movl	%edx, (%ecx)		# column pointer (division rest)

	ret



	# void cursor_set_position(unsigned row, unsigned column)
	.global	cursor_set_position
cursor_set_position:

	# translate the coordinates to a position.
	movl	4(%esp), %eax		# row
	movw	$80, %cx
	mulw	%cx
	movw	%ax, %cx

	movl	8(%esp), %eax		# column
	addw	%ax, %cx

	# set the position.
	movb	$0x0f, %al
	movw	$0x03d4, %dx
	outb	%al, %dx

	incw	%dx
	movb	%cl, %al
	outb	%al, %dx

	decw	%dx
	movb	$0x0e, %al
	outb	%al, %dx

	incw	%dx
	movb	%ch, %al
	outb	%al, %dx

	ret
