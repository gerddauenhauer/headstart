headstart: bootsector.o bootloader.o
	ld	-o headstart bootsector.o bootloader.o -Theadstart.ld
	chmod	644 headstart

bootsector.o: bootsector.s
	as	-o bootsector.o bootsector.s

bootloader.o: bootloader.s
	as	-o bootloader.o bootloader.s

clean:
	rm	-f domain headstart headstart.offset *.o
