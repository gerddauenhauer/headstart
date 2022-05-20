	# headstart: minimalistic multiboot (0.6.96) compliant boot loader.
	# (c) 2022, gerd dauenhauer
	# SPDX 0BSD, see the enclosed LICENSE file

	.section .bootloader

	.code16

	# the (second stage) bootloader expects these arguments:
	# %ax = bootloader size
	# %bx = boot drive index
	movw	%ax, bootloader_size
	movw	%bx, drive_index

	movw	$(0x07c0 + 0x0020), bootloader_base


	# provide a temporary stack.
	movw	$0x07c0, %ax		# end of bootsector should be free now
	movw	%ax, %ss
	movw	$0x0200, %sp


	# initialize other segment registers.
	movw	%ax, %ds


	# announce ourselves.
	movw	$start_bootloader_message, %ax
	call	print_message


	# determine the available base memory.
	clc

	int	$0x12

	jc	_get_base_memory_error

	movw	%ax, base_memory_kib	# %ax has usable size in kib up to ebda

	jmp	prepare_multiboot_header

_get_base_memory_error:
	movw	$get_base_memory_failed_message, %ax
	call	panic_message



prepare_multiboot_header:
	# place the multiboot structure up in the highest kib of base memory.
	movw	base_memory_kib, %ax
	decw	%ax
	shlw	$6, %ax
	movw	%ax, multiboot_base
	movw	%ax, %es


	# zero out the multiboot header.
	movw	$(116 / 2), %cx
	xorw	%di, %di		# %es has multiboot_base
	xorw	%ax, %ax
	rep
	stosw


	# fill in the mem information.
	xorl	%eax, %eax
	movw	base_memory_kib, %ax
	movl	%eax, %es:8		# mem_upper

	movl	%es:0, %eax		# flags
	orl	$0x00000001, %eax
	movl	%eax, %es:0


	# fill in the boot_device information.
	movb	drive_index, %al
	shll	$24, %eax
	orl	$0x00ffffff, %eax	# assume one harddisk, no partitions
	movl	%eax, %es:12		# boot_device

	movl	%es:0, %eax		# flags
	orl	$0x00000002, %eax
	movl	%eax, %es:0


	# fill in the command line information.
	movl	%es, %edi		# %es has multiboot_base
	shll	$4, %edi		# convert to zero-based 32 bit pointer
	addl	$116, %edi		# put cmdline after multiboot structure
	movl	%edi, %es:16

	movw	bootloader_size, %si
	addw	$(512 - 50 - 4), %si
	movw	$116, %di
	movw	$50, %cx		# max size of cmdline

	rep
	movsb

	movb	$0x00, %es:4(%di)	# zero terminate

	movl	%es:0, %eax		# flags
	orl	$0x00000004, %eax
	movl	%eax, %es:0


	# fill in the mmap information.
	movl	%es:(16), %edi		# cmdline
	addl	$(50 + 4), %edi		# put mmap after cmdline
	movl	%edi, %es:48

	movl	$(116 + 50 + 4 + 4), %edi
	xorl	%ebx, %ebx		# first smap entry

_fill_mmap_get_memory_map_next:
	movl	$0xe820, %eax		# get memory map
	movl	$24, %ecx		# size of an entry is 20/24 bytes
	movl	$0x534d4150, %edx	# 'SMAP'
	clc

	int	$0x15

	jc	_fill_mmap_get_memory_map_error

	movl	$0x534d4150, %edx
	cmpl	%eax, %edx
	jne	_fill_mmap_get_memory_map_error

	test	%ebx, %ebx
	jz	_fill_mmap_get_memory_map_done

	movl	%ecx, %es:-4(%di)	# mmap entry size (20/24 bytes)

	addw	%cx, %di
	addw	$4, %di

	jmp	_fill_mmap_get_memory_map_next

_fill_mmap_get_memory_map_error:
	movw	$get_memory_map_failed_message, %ax
	call	panic_message

_fill_mmap_get_memory_map_done:

	subl	$(116 + 50 + 4 + 4), %edi
	movl	%edi, %es:44		# mmap_length

	movl	%es:0, %eax		# flags
	orl	$0x00000040, %eax
	movl	%eax, %es:0


	# fill in the boot_loader_name information.
	movl	%es:(48), %edi		# mmap_addr
	movl	%es:(44), %eax		# mmap_length
	addl	%eax, %edi		# put boot_loader_name after mmap
	movl	%edi, %es:64

	movw	$boot_loader_name, %si

	movw	$(116 + 50 + 4), %di
	addw	%ax, %di

_fill_boot_loader_name_next:
	lodsb
	stosb

	cmpb	$0x20, %al
	jge	_fill_boot_loader_name_next

	movb	$0x00, %es:-1(%di)	# zero terminate

	movl	%es:0, %eax		# flags
	orl	$0x00000200, %eax
	movl	%eax, %es:0



load_kernel:
	# prepare basic data for the kernel.
	movw	bootloader_base, %ax
	movw	bootloader_size, %bx
	addw	$(512 - 1), %bx
	shrw	$9, %bx
	shlw	$5, %bx
	addw	%bx, %ax
	movw	%ax, kernel_base

	movw	bootloader_base, %cx
	movw	%cx, %fs
	shlw	$4, %bx
	subw	$4, %bx
	movl	%fs:(%bx), %eax		# access kernel size,
	movl	%eax, kernel_size	# stored in bootloader


	# check that the kernel size fits in the available memory.
	xorl	%ebx, %ebx
	movw	multiboot_base, %bx
	movw	kernel_base, %cx
	subw	%cx, %bx
	shll	$4, %ebx

	cmpl	%eax, %ebx

	jge	_load_kernel

	movw	$load_kernel_size_message, %ax
	call	panic_message
	

_load_kernel:
	# announce ourselves.
	movw	$load_kernel_message, %ax
	call	print_message


	# check for int 13h extensions to use lba mode.
	movb	$0x41, %ah		# int 13h extensions
	movw	$0x55aa, %bx
	movb	drive_index, %dl
	clc

	int	$0x13

	jc	_load_sectors_error

	andb	$0x01, %cl		# lba mode supported
	testb	%cl, %cl
	jz	_load_sectors_error


	# read multiple kernel sectors in up to segment chunks.
	movw	kernel_base, %bx
	movw	%bx, disk_address_packet_structure_transfer_buffer_base
	xorl	%ebx, %ebx
	movw	kernel_base, %bx
	subw	$0x07c0, %bx
	shrw	$5, %bx
	movl	%ebx, disk_address_packet_structure_lba_low

	movw	$disk_address_packet_structure, %si
	movb	drive_index, %dl

	movl	kernel_size, %ebx
	addl	$(512 - 1), %ebx
	shrl	$9, %ebx
	movl	$127, %ecx		# 127 sectors = 64kib


_load_next_sectors:
	testl	%ebx, %ebx
	jz	find_header

	cmpl	%ebx, %ecx
	jbe	_load_127_sectors

	movw	%bx, %cx		# final sectors

_load_127_sectors:
	movb	$0x42, %ah		# read sectors (lba)
	movw	%cx, disk_address_packet_structure_sector_count
	clc

	int	$0x13

	jc	_load_sectors_error

	subl	%ecx, %ebx
	addl	%ecx, disk_address_packet_structure_lba_low
	addw	$0x1000, disk_address_packet_structure_transfer_buffer_base

	jmp	_load_next_sectors

_load_sectors_error:
	movw	$load_kernel_failed_message, %ax
	call	panic_message



find_header:
	movw	kernel_base, %cx
	movw	%cx, %es
	movl	$0, %esi
	movl	kernel_size, %edi	# scan up to min(8192, <kernel size>)
	subl	$48, %edi

_find_header_next:
	cmpw	$(8192 - 48), %si
	je	_find_header_error

	cmpl	%esi, %edi
	je	_find_header_error

	movl	%es:(%si), %eax
	cmpl	$0x1badb002, %eax
	jne	_find_header_loop

	movl	%es:4(%si), %ebx
	addl	%ebx, %eax
	movl	%es:8(%si), %ebx
	addl	%ebx, %eax
	jmp	decode_header

_find_header_loop:
	addw	$4, %si
	jmp	_find_header_next

_find_header_error:
	movw	$find_header_failed_message, %ax
	call	panic_message
	


decode_header:
	movl	%es:4(%si), %ebx
	cmpl	$0x00000002, %ebx		# only guarantee to provide
	jne	_decode_header_flags_error	# memory information

	movl	%es:12(%si), %eax
	movl	%eax, kernel_multiboot_header_addr

	movl	%es:16(%si), %eax
	movl	%eax, kernel_multiboot_load_addr

	movl	%es:20(%si), %eax
	movl	%eax, kernel_multiboot_load_end_addr

	movl	%es:24(%si), %eax
	movl	%eax, kernel_multiboot_bss_end_addr

	movl	%es:28(%si), %eax
	movl	%eax, kernel_multiboot_entry_addr


	# check that extracted kernel fits in the available memory.
	xorl	%ebx, %ebx
	movw	multiboot_base, %bx
	shll	$4, %ebx
	cmpl	%ebx, %eax
	jg	_decode_header_size_error


	# rescue the cursor position's current offset.
	movb	$0x03, %ah
	xorw	%bx, %bx

	int	$0x10

	movw	%dx, %cx		# %dx overwritten by multiplication
	xorw	%ax, %ax
	movb	%ch, %al		# row (was in %dh)
	movw	$80, %bx
	mulw	%bx
	xorb	%ch, %ch
	addw	%cx, %ax		# column (was in %dl)
	shlw	$1, %ax			# two bytes per character
	movw	%ax, screen_position


	# but we advance the hardware cursor for the kernel to pick up.
	movb	$0x03, %ah
	xorw	%bx, %bx

	int	$0x10

	movb	$0x02, %ah
	xorw	%bx, %bx
	incb	%dh
	movb	$0, %dl

	int	$0x10


	jmp	switch_to_protected_mode

_decode_header_flags_error:
	movw	$decode_header_failed_message, %ax
	call	panic_message

_decode_header_size_error:
	movw	$extract_kernel_size_message, %ax
	call	panic_message



	.align	4
bootloader_base:
	.skip	2

bootloader_size:
	.skip	2

drive_index:
	.skip	1



	.align	4
disk_address_packet_structure:
disk_address_packet_structure_size:
	.byte	16
disk_address_packet_structure_unused:
	.byte	0
disk_address_packet_structure_sector_count:
	.skip	2			# 127 sectors at most, 127 * 512 = 64kib
disk_address_packet_structure_transfer_buffer_address:
	.word	0
disk_address_packet_structure_transfer_buffer_base:
	.skip	2
disk_address_packet_structure_lba_low:
	.skip	4
disk_address_packet_structure_lba_high:
	.long	0



	.align	2
base_memory_kib:
	.skip	2



	.align	2
multiboot_base:
	.skip	2			# points to a multiboot structure

	.align	4
multiboot_mmap_address:
	.skip	4			# mmap follows the multiboot structure

	.align	4
multiboot_boot_loader_name_address:
	.skip	4			# boot_loader_name
					# follows the multiboot mmap


	.align	2
kernel_base:
	.skip	2

	.align	4
kernel_size:
	.skip	4



	.align	4
kernel_multiboot:			# data extracted from the kernel
kernel_multiboot_header_addr:
	.skip	4
kernel_multiboot_load_addr:
	.skip	4
kernel_multiboot_load_end_addr:
	.skip	4
kernel_multiboot_bss_end_addr:
	.skip	4
kernel_multiboot_entry_addr:
	.skip	4



	.align	4
screen_position:			# memory address for next character
	.skip	4



	# from now on we are in protected mode, using a flat memory model.
	# whenever we take an address, we must add the 0x7c00 to account
	# for the segment offset used in real mode before.
	.align	4
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
	.long	0x7c00 + gdt_begin



	nop
	nop
	nop
	nop



switch_to_protected_mode:
	cli

	movw	$0x07c0, %ax		# gdt in real mode still
	movw	%ax, %ds		# referenced from %ds
	lgdt	gdt_list

	movl	%cr0, %eax
	orl	$0x00000001, %eax
	movl	%eax, %cr0		# now in protected mode


	ljmp	$(gdt_code - gdt_begin),$(0x7c00 + clear_pipeline)



	.code32

clear_pipeline:
	movw	$(gdt_data - gdt_begin), %ax
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %fs
	movw	%ax, %gs

	movw	$(gdt_stack - gdt_begin), %ax
	movw	%ax, %ss


	# announce ourselves.
	movl	$(0x7c00 + 0x0200), %esp
	call	print_dot
	movl	%edi, %ebp		# %edi still has address of last dot


	# set machine state according to multiboot specification.
	inb	$0x92, %al
	orb	$0x02, %al
	outb	%al, $0x92		# enable a20 gate

	inb	$0x70, %al
	andb	$0x7f, %al
	outb	%al, $0x70		# enable nmi


	# provide some small stack for arguments to pass to the thunk.
	xorl	%esp, %esp
	movw	(0x7c00 + base_memory_kib), %sp
	shll	$10, %esp		# use stack right at end of base memory


	# save the kernel's multiboot addresses and sizes.
	movl	(0x7c00 + kernel_multiboot_load_addr), %edi
	movl	(0x7c00 + kernel_multiboot_load_end_addr), %ecx
	movl	%edi, %ebx
	subl	%ebx, %ecx
	addl	$(4 - 1), %ecx
	andl	$0xfffffffc, %ecx	# size of data to load, rounded to long

	xorl	%esi, %esi
	movw	(0x7c00 + kernel_base), %si
	shll	$4, %esi		# begin of image including elf header
	addl	%edi, %esi		# begin of data to load

	movl	(0x7c00 + kernel_multiboot_bss_end_addr), %edx
	addl	%ecx, %ebx
	subl	%ebx, %edx
	addl	$(4 - 1), %edx
	andl	$0xfffffffc, %edx	# size to initialize, rounded to long

	xorl	%ebx, %ebx
	movw	(0x7c00 + multiboot_base), %bx
	shll	$4, %ebx		# data to pass to kernel


	pushl	(0x7c00 + kernel_multiboot_entry_addr)
	pushl	%ebx			# address of multiboot structure to pass
	pushl	%ebp			# location of progress dot
	pushl	%esi			# source address of kernel data to load
	pushl	%ecx			# size of kernel data to load
	pushl	%edx			# size of kernel data to initialize
	pushl	%edi			# target address of kernel


	jmp	move_kernel_thunk



	# leaves cursor address in %edi
print_dot:
	movl	$0x00b8000, %edi	# video ram begin

	# print the dot.
	xorl	%eax, %eax
	movw	(0x00007c00 + screen_position), %ax
	addl	%eax, %edi
	movw	$(0x0700 + '. ), %ax	# gray dot on black - dos default colors
	stosw

	movl	%edi, %eax		# update offset
	subl	$0x00b8000, %eax
	movw	%ax, (0x00007c00 + screen_position)

	ret



	.align	4
kernel_thunk_begin:
	popl	%edi			# target address of kernel
	popl	%edx			# size of kernel data to initialize
	popl	%ecx			# size of kernel data to load
	popl	%esi			# source address of kernel data to load

	#FIXME up/down

	# move the kernel .text, .data, .rodata segments.
	shrl	$2, %ecx
	rep
	movsl

	# zero-initialize the kernel .bss segment.
	movl	%edx, %ecx
	shrl	$2, %ecx
	xorl	%eax, %eax
	rep
	stosl

	# announce ourselves.
	popl	%edi
	movw	$(0x0700 + '. ), %ax	# gray dot on black - dos default colors
	stosw

	# set machine state according to multiboot specification.
	movl	$0x2badb002, %eax
	popl	%ebx

	# call the kernel.
	ret				# does not return
kernel_thunk_end:



move_kernel_thunk:
	# get the thunk source.
	movl	$kernel_thunk_begin, %esi
	addl	$0x7c00, %esi

	# get the thunk size.
	movl	$(kernel_thunk_end - kernel_thunk_begin), %ecx
	addl	$3, %ecx
	andl	$0xfffffffc, %ecx

	# get the thunk destination.
	movl	%esp, %edi		# right before stack of parameters
	subl	%ecx, %edi		# at end of base memory
	movl	%edi, %edx

	# move the thunk out of the way.
	shrl	$2, %ecx
	rep
	movsl

	# jump to the moved thunk.
	jmp	*%edx			# does not return



boot_loader_name:			# reuse for boot_load_name
start_bootloader_message:		# in multiboot header
	.asciz	"headstart (b/0)"

get_base_memory_failed_message:
	.asciz "\n\rCOULD NOT GET BASE MEMORY"

load_kernel_size_message:
	.asciz	"\n\rKERNEL IS TOO BIG TO LOAD"

get_memory_map_failed_message:
	.asciz "\n\rCOULD NOT GET MEMORY MAP"

load_kernel_failed_message:
	.asciz "\n\rCOULD NOT LOAD KERNEL"

find_header_failed_message:
	.asciz "\n\rKERNEL HAS NO MULTIBOOT SIGNATURE"

decode_header_failed_message:
	.asciz "\n\rKERNEL HAS INVALID MULTIBOOT HEADER"

extract_kernel_size_message:
	.asciz	"\n\rKERNEL IS TOO BIG TO EXTRACT"

load_kernel_message:
	.asciz	"\n\rloading."
