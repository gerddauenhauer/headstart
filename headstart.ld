OUTPUT_FORMAT("binary")
ENTRY(start)

SECTIONS
{
	. = 0;
	.bootsector :
	{
		*(.bootsector)

		. = 508;
		/* bootloader size */
		SHORT(__bootloader_end - __bootloader_begin)

		. = 510;
		BYTE(0x55)
		BYTE(0xaa)
	}

	. = 512;
	.bootloader :
	{
		__bootloader_begin = .;

		*(.bootloader)

		. += 50;
		/* reserved for optional command line */

		/* reserved for kernel size */
		LONG(0)

		. = ALIGN(512);
		__bootloader_end = .;
	}

	/* the actual kernel to load is pasted onto the bootloader
	 * as an uninterpreted binary data blob. the kernel size is
	 * written to the last 4 bytes of the bootloader, see above.
	 * the command line is optional and preceedes the size. */
}
