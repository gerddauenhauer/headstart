	# headstart: minimalistic multiboot (0.6.96) compliant boot loader.
	# (c) 2022, gerd dauenhauer
	# SPDX 0BSD, see the enclosed LICENSE file

	.section .bootsector

	.code16

	.global	start
start:
	ljmp	$0x07c0,$load_cs


load_cs:
	# initialize other segment registers that we use.
	movw	$0x07c0, %ax
	movw	%ax, %ds


	# provide a temporary stack.
	movw	%ax, %ss
	movw	$(0x0200 - 4), %sp	# last 4 bytes are occupied


	# disable the cursor to save us some work in protected mode later.
	movb	$0x01, %ah
	movb	$0x3f, %ch

	int	$0x10


	# announce ourselves.
	movw	$load_bootloader_message, %ax
	call	print_message


	# get boot drive parameters from bios.
	movb	%dl, drive_index	# %dl holds the boot drive index
	movb	$0x08, %ah
	clc

	int	$0x13

	jc	_load_error

	movb	%dh, drive_head_count
	movb	%cl, %al
	andb	$0x3f, %al		# 6 bits for the sector count
	movb	%al, drive_sector_per_track_count
	shrw	$6, %cx			# 10 bits for the cylinder count
	movw	%cx, drive_cylinder_count


	# prepare basic data for the bootloader.
	movw	508, %bx		# access the bootloader size,
	movw	%bx, bootloader_size	# stored within the bootsector


	# the bios only loads the first sector,
	# so we load the missing bootloader sectors manually.
	movw	$0, %di			# first cylinder
	movb	$2, %cl			# *second* sector
	movb	$0, %dh			# first head
	movb	drive_index, %dl
	movw	$(0x07c0 + 0x0020), %bx
	movw	%bx, %es		# target = %es:%bx
	xorw	%bx, %bx

_load_next_sector:
	movb	$0x02, %ah		# read sectors (chs)
	movb	$1, %al			# one sector
	andw	$0x003f, %cx		# %cx has 10 bits for the cylinder
	shlw	$6, %di			# and 6 bits for the sector
	orw	%di, %cx
	shrw	$6, %di
	clc

	int	$0x13

	jc	_load_error

	addw	$512, %bx
	cmpw	bootloader_size, %bx
	jge	_load_done

	incb	%cl
	cmpb	drive_sector_per_track_count, %cl
	jg	_load_next_cylinder

	jmp	_load_next_sector

_load_next_cylinder:
	movb	$1, %cl			# back to first sector
	incw	%di			# next cylinder
	cmpw	drive_cylinder_count, %di
	jge	_load_next_head

	jmp	_load_next_sector

_load_next_head:
	movw	$0, %di			# back to first cylinder
	incb	%dh			# next head
	
	jmp	_load_next_sector

_load_error:
	movw	$load_failed_message, %si
	call	panic_message

_load_done:


	# call the (second stage) bootloader.
	xorl	%eax, %eax
	movw	bootloader_size, %ax
	movw	drive_index, %bx

	ljmp	$0x07c0,$0x0200		# does not return


	
	# %ax = pointer to message
	.global	print_message
print_message:
	pushw	%si
	pushw	%bx

	movw	%ax, %si

_print_message_next:
	lodsb
	test	%al, %al
	je	_print_message_done

	movb	$0x0e, %ah		# teletype output
	xorw	%bx, %bx

	int	$0x10

	jmp	_print_message_next

_print_message_done:

	popw	%bx
	popw	%si
	ret



	# %ax = pointer to message
	.global	panic_message
panic_message:
	call	print_message

_panic_message_halt:
	hlt
	jmp	_panic_message_halt



drive_index:
	.skip	1

drive_head_count:
	.skip	1			# 0..255 at most,
					# but 255 invalid due to a bug in ms-dos
drive_cylinder_count:
	.skip	2			# 0..1024 at most

drive_sector_per_track_count:
	.skip	1			# 1..63 at most



bootloader_size:
	.skip	2



load_bootloader_message:
	.asciz	"loading\n\r"

load_failed_message:
	.asciz "COULD NOT LOAD BOOTLOADER"
