headstart (b/0)
===============
Motivation
----------
This project provides a rudimentary bootloader, based on the [multiboot specification, version 0.6.96](<https://www.gnu.org/software/grub/manual/multiboot/multiboot.html>).
It came to life as a byproduct while experimenting with some small real-time kernels under the [Xen hypervisor](<https://xenproject.org>).
Somehow it just felt inappropriate to use a full blown boot loader such as the [GRUB](<https://www.gnu.org/software/grub>) or [U-Boot](<https://www.denx.de/wiki/U-Boot>) that are many times the size of the actual kernels that they are supposed to load.
And as often, "just because" is a good enough reason to start such a project. And it gives some oppoprtunity to learn new things, as well.

Overview
--------
The name of the bootloader comes from the fact that it is pasted onto the *head* of the kernel that it should *start*.
It might also be faster than other bootloaders and thus give your kernel a *headstart* as well...
The extension indicates that it uses the *B*IOS and implements the multiboot specification, version *0*.6.96.

The code relies on x86 BIOS functionality as in the olden days.
It comprises two parts:

- `bootsector.s` implements the first stage and is loaded by the BIOS code automatically.
It is marked with the magic bytes `0x55 0xAA` at its end such that the BIOS identifies it as bootable code.
Since the firsts tage must fit within 512 bytes, it is too small for most cases.
It thus does not load the kernel but instead loads the second stage boot loader code.
- `bootloader.s` implements the second stage that must be loaded manually.
It implements the mandatory multiboot features such as identifying the available RAM.
In order to keep the code simple, the second stage code is not aware of any file system semantics.
Instead, It simply keeps loading raw disk sectors follonwing the bootloader code.
How many of these sectors does the kernel code comprise? the kernel size must be patched into the last four bytes of the bootloader - there is a simple shell-skript `patch-kernel-size.sh` included for this purpose.

To get started, the project includes a simple demo "kernel" that shows information that it receives from the bootloader via the multiboot protocol.
The demo can be executed as a Xen domain, as well as on bare metal.
It probably works in many other environments as well.

Building
--------

To see what the assembler and linker produces, `objdump` is pretty good in producing the assembly code again:

    $ objdump -b binary -mi386 -Maddr16,data16 -D headstart
