# Issue

It appears that binaries compiled with musl break afl-qemu-trace forkserver
behaviour.

When a target static musl binary is run with AFL_ENTRYPOINT defined,
all non-crashing test inputs will all produce a crash after a crashing test
input is run. This would suggest that something between _start() and main()
is causing an issue for the forkserver.

## AFLplusplus

This issue is tested against AFLplusplus dev branch. AFLplusplus is compiled
with:

```
CPU_TARGET=x86_64 make binary-only -j `nproc`
```

## Demonstrating the issue

First observe correct behaviour with a static binary compiled with gcc...

```
make gcc-x86_64-run
```

The above will compile main.c with gcc, and then run afl-showmap against it
using a batch of test cases:

* 3 non-crashing cases
* 1 crashing case (the program calls raise(SIGABRT))
* 3 non-crashing cases

It will be observed from the output that there are 3 successful runs,
followed by an uncaught signal 6, then 3 successful runs.

Then using a static binary compiled with musl-gcc...

```
make musl-x86_64-run-bad
```

The above will cause multiple uncaught signal 6 from good inputs.

Removing the AFL_ENTRYPOINT directive resolves the problem...

```
make musl-x86_64-run-good
```

## Output

```
$ make musl-x86_64-run-bad
AFL_DEBUG_CHILD=1 AFL_DEBUG=1 afl-showmap -o .traces -Q -I .filelist.1 -- ./musl-x86_64 @@ </dev/null
[D] DEBUG:  afl-showmap -o .traces -Q -I .filelist.1 -- ./musl-x86_64 @@
afl-showmap++4.08a by Michal Zalewski
[*] Executing './musl-x86_64'...
[+] Enabled environment variable AFL_DEBUG_CHILD with value 1
[*] Spinning up the fork server...
AFL forkserver entrypoint: 0x401038
Debug: Sending status c201ffff
[+] All right - fork server is up.
[*] Extended forkserver functions received (c201ffff).
[*] Target map size: 65536
[*] Reading from file list '.filelist.1'...
[+] Enabled environment variable AFL_DEBUG with value 1
[D] DEBUG: /home/forky2/projects/afl/afl-qemu-trace: "./musl-x86_64" "/home/forky2/projects/afl-issue/./.afl-showmap-temp-167744"
[*] Reading from '.filelist.1'...
Getting coverage for 'in/ok'
-- Program output begins --
-- Program output ends --
Getting coverage for 'in/ok'
-- Program output begins --
-- Program output ends --
Getting coverage for 'in/ok'
-- Program output begins --
-- Program output ends --
Getting coverage for 'in/sigabrt'
-- Program output begins --
qemu: uncaught target signal 6 (Aborted) - core dumped
-- Program output ends --

+++ Program killed by signal 6 +++
[!] WARNING: crashed: in/sigabrt
Getting coverage for 'in/ok'
-- Program output begins --
-- Program output ends --
Getting coverage for 'in/ok'
-- Program output begins --
-- Program output ends --
Getting coverage for 'in/ok'
-- Program output begins --
-- Program output ends --
[+] Processed 7 input files.
[+] Captured 216 tuples (map size 65536, highest value 6, total values 1642) in '.traces'.
```
