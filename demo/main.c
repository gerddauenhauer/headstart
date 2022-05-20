/* demo kernel: verify basic functions of a multiboot compliant boot loader.
 * (c) 2022, gerd dauenhauer
 * SPDX 0BSD, see the enclosed LICENSE file
 *
 * this file provides the "kernel" that executes once the assembly startup
 * code is finished. it does not do much useful, though - it's main() function
 * just prints some information that it gets from the bootloader. */

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include <multiboot.h>

extern const struct multiboot_info *multiboot_info;

extern const int __text_begin;
extern const int __text_end;

extern const int __rodata_begin;
extern const int __rodata_end;

extern const int __data_begin;
extern const int __data_end;

extern const int __bss_begin;
extern const int __bss_end;

static void print_uint32_memory_region(
	uint32_t begin, uint32_t end, const char *label)
{
	uint32_t len = end - begin;
	char *fac;

	if (len > 10UL * 1024UL * 1024UL) {
		fac = "m";
		len /= 1024UL * 1024UL;
	} else if (len > 10UL * 1024UL) {
		fac = "k";
		len /= 1024UL;
	} else {
		fac = " ";
	}
	printf("  %08x..%08x = %4u%s %s\n",
		begin, end, len, fac, label ? label : "");
}

static void print_uint64_memory_region(
	uint64_t begin, uint64_t end, const char *label)
{
	uint64_t len = end - begin;
	char *fac;

	if (len > 10ULL * 1024ULL * 1024ULL * 1024ULL) {
		fac = "g";
		len /= 1024ULL * 1024ULL * 1024ULL;
	} else if (len > 10ULL * 1024ULL * 1024ULL) {
		fac = "m";
		len /= 1024ULL * 1024ULL;
	} else if (len > 10ULL * 1024ULL) {
		fac = "k";
		len /= 1024ULL;
	} else {
		fac = " ";
	}
	printf("  %016lx..%016lx = %4lu%s %s\n",
		begin, end, len, fac, label ? label : "");
}

int main(void)
{
	printf("demo kernel\n");
	if (multiboot_info->flags & MULTIBOOT_INFO_BOOT_LOADER_NAME)
		printf("loaded by %s\n",
			(const char *)multiboot_info->boot_loader_name);

	if (multiboot_info->flags & MULTIBOOT_INFO_MEMORY) {
		printf("base memory:\n");
		print_uint32_memory_region(
			multiboot_info->mem_lower * 1024,
			multiboot_info->mem_upper * 1024, NULL);
	}

	if (multiboot_info->flags & MULTIBOOT_INFO_BOOTDEV) {
		uint8_t device = (multiboot_info->boot_device >> 24);
		const char *label;

		if (device >= 0x80U && device <= 0x8fU)
			label = "hd";
		else if (device <= 0x0fU)
			label = "fd";
		else
			label = "?";
		device &= 0x0f;
		printf("booted from (%s%u)\n", label, (unsigned)device);
	}

	if (multiboot_info->flags & MULTIBOOT_INFO_CMDLINE)
		printf("command line = \"%s\"\n",
			(const char *)multiboot_info->cmdline);

	if (multiboot_info->flags &  MULTIBOOT_INFO_MEM_MAP) {
		uint32_t entry_count;
		struct multiboot_mmap_entry *entry;
		size_t i;

		printf("memory map:\n");
		entry_count = multiboot_info->mmap_length / sizeof *entry;
		entry = (void *)multiboot_info->mmap_addr;
		for (i = 0; i < entry_count; ++i) {
			const char *label;

			switch (entry->type) {
			case MULTIBOOT_MEMORY_AVAILABLE:
				label = "ram";
				break;
			case MULTIBOOT_MEMORY_RESERVED:
				label = "reserved";
				break;
			case MULTIBOOT_MEMORY_ACPI_RECLAIMABLE:
				label = "acpi";
				break;
			case MULTIBOOT_MEMORY_NVS:
				label = "nv ram";
				break;
			case MULTIBOOT_MEMORY_BADRAM:
				label = "bad ram";
				break;
			default:
				label = "?";
				break;
			}

			print_uint64_memory_region(
				entry->addr, entry->addr + entry->len, label);

			++entry;
		}
	}

	printf("sections:\n");
	print_uint32_memory_region(
		(uint32_t)&__text_begin, (uint32_t)&__text_end, ".text");
	print_uint32_memory_region(
		(uint32_t)&__rodata_begin, (uint32_t)&__rodata_end, ".rodata");
	print_uint32_memory_region(
		(uint32_t)&__data_begin, (uint32_t)&__data_end, ".data");
	print_uint32_memory_region(
		(uint32_t)&__bss_begin, (uint32_t)&__bss_end, ".bss");
}
