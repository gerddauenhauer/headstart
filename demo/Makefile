demo.image: ../headstart kernel
	cp	../headstart demo.image
	cat	kernel >> demo.image
	../patch-kernel-size.sh demo.image kernel
	../patch-command-line.sh demo.image "additional kernel parameters"

../headstart:
	( cd .. && make )

kernel: runtime.o libc.o main.o
	ld	-melf_i386 -nostdlib -o kernel runtime.o libc.o main.o -Tkernel.ld
	chmod	644 kernel

runtime.o: runtime.S
	cc	-m32 -isystem./include -c runtime.S

libc.o: libc.c
	cc	-m32 -isystem./include -fno-builtin -Wall -Wextra -pedantic -std=c99 -c libc.c

main.o: main.c
	cc	-m32 -isystem./include -fno-builtin -Wall -Wextra -pedantic -std=c99 -c main.c

clean:
	rm	-f demo.image headstart kernel *.o
