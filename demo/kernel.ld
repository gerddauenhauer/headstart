OUTPUT_FORMAT("elf32-i386")
OUTPUT_ARCH(i386)

SECTIONS
{
	. = 0x1000;

	.text :
	{
		__text_begin = ABSOLUTE(.);
		*(.multiboot)
		*(.text)
		__text_end = ABSOLUTE(.);
	}

	.rodata :
	{
		__rodata_begin = ABSOLUTE(.);
		*(.rodata)
		__rodata_end = ABSOLUTE(.);
	}

 	.data :
	{
 		__data_begin = ABSOLUTE(.);
		*(.data)
		__data_end = ABSOLUTE(.);
 	}

 	.bss :
	{
		__kernel_stack_begin = ABSOLUTE(.);
		. += 2048;
		__kernel_stack_end = ABSOLUTE(.);

		__bss_begin =  ABSOLUTE(.);
		*(.bss)
		__bss_end =  ABSOLUTE(.);
 	}
}
