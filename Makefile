gcc-x86_64: main.c
	gcc -o gcc-x86_64 -static main.c

.musl-x86_64/musl/bin/musl-gcc:
	git submodule update --init
	mkdir -p .musl-x86_64
	cd .musl-x86_64; ../musl/configure --prefix=$(PWD)/.musl-x86_64/musl
	make -C .musl-x86_64 install

musl-x86_64: main.c .musl-x86_64/musl/bin/musl-gcc
	.musl-x86_64/musl/bin/musl-gcc -o musl-x86_64 -static main.c
	
gcc-x86_64-run: gcc-x86_64
	mkdir -p .traces
	AFL_DEBUG_CHILD=1 AFL_DEBUG=1 AFL_ENTRYPOINT=`afl-qemu-trace ./gcc-x86_64 | grep AFL_ENTRYPOINT | cut -d " " -f 2` afl-showmap -o .traces -Q -I .filelist.1 -- ./gcc-x86_64 @@ </dev/null

musl-x86_64-run-bad: musl-x86_64
	mkdir -p .traces
	AFL_DEBUG_CHILD=1 AFL_DEBUG=1 AFL_ENTRYPOINT=`afl-qemu-trace ./musl-x86_64 | grep AFL_ENTRYPOINT | cut -d " " -f 2` afl-showmap -o .traces -Q -I .filelist.1 -- ./musl-x86_64 @@ </dev/null

musl-x86_64-run-good: musl-x86_64
	mkdir -p .traces
	AFL_DEBUG_CHILD=1 AFL_DEBUG=1 afl-showmap -o .traces -Q -I .filelist.1 -- ./musl-x86_64 @@ </dev/null
