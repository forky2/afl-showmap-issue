# Issue

Binaries compiled with musl break afl-qemu-trace forkserver behaviour.

When a target static musl binary is run with AFL_ENTRYPOINT defined,
all non-crashing test inputs will produce a crash after a crashing test
input is run.

## Cause

Unlike GLIBC which will always make a syscall to gettid for its TID, musl
caches a thread's TID in the TLS. This is fine for normal fork operations as
musl will update the TLS after the fork with a syscall to gettid. However,
in the magical case where QEMU is forking the process unbeknownst to the guest
process, the child process will keep an invalid TID and use it in calls such as
`tkill(int tid, int sig)`.

## Remediation

Whilst we might prefer that musl had not implemented its TID recording in this
way I don't think this is a musl bug. I propose that the syscall translation in
qemuafl modifies such spurious syscalls so that they behave as intended.

By way of example:
* Say the QEMU forkserver parent TID is 10 just before forking.
* And the QEMU forkserver child TID is 15 just after forking.
* Keep these two values in globals so that when a call to __safe_tkill() is made
  * the value of arg1 is compared to parent TID.
  * if and only if they are equal, arg1 is replaced with the recorded value of
    child TID.

I have done a proof of concept of this which is successful at resolving the
issue, but it is a bit messy.

I've only tested a fix for tkill in linux-user. I've not done it for other
syscalls that take a TID nor have I looked into bsd-user.

## Testing baseline

This issue was tested against AFLplusplus dev branch. AFLplusplus is compiled
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
AFL_DEBUG_CHILD=1 AFL_DEBUG=1 AFL_ENTRYPOINT=`afl-qemu-trace ./musl-x86_64 | grep AFL_ENTRYPOINT | cut -d " " -f 2` afl-showmap -o .traces -Q -I .filelist.1 -- ./musl-x86_64 @@ </dev/null
[D] DEBUG:  afl-showmap -o .traces -Q -I .filelist.1 -- ./musl-x86_64 @@
afl-showmap++4.08a by Michal Zalewski
[*] Executing './musl-x86_64'...
[+] Enabled environment variable AFL_DEBUG_CHILD with value 1
[*] Spinning up the fork server...
AFL forkserver entrypoint: 0x40115f
Debug: Sending status c201ffff
[+] All right - fork server is up.
[*] Extended forkserver functions received (c201ffff).
[*] Target map size: 65536
[*] Reading from file list '.filelist.1'...
[+] Enabled environment variable AFL_DEBUG with value 1
[D] DEBUG: /home/forky2/projects/afl/afl-qemu-trace: "./musl-x86_64" "/home/forky2/projects/afl-issue/./.afl-showmap-temp-798707"
[*] Reading from '.filelist.1'...
Getting coverage for 'in/ok'
-- Program output begins --
Guest process believes PID: 798710 TID: 798708
-- Program output ends --
Getting coverage for 'in/ok'
-- Program output begins --
Guest process believes PID: 798711 TID: 798708
-- Program output ends --
Getting coverage for 'in/ok'
-- Program output begins --
Guest process believes PID: 798712 TID: 798708
-- Program output ends --
Getting coverage for 'in/sigabrt'
-- Program output begins --
Guest process believes PID: 798713 TID: 798708
-- Program output ends --
Getting coverage for 'in/ok'
-- Program output begins --
qemu: uncaught target signal 6 (Aborted) - core dumped
-- Program output ends --

+++ Program killed by signal 6 +++
[!] WARNING: crashed: in/ok
Getting coverage for 'in/ok'
-- Program output begins --
qemu: uncaught target signal 6 (Aborted) - core dumped
-- Program output ends --

+++ Program killed by signal 6 +++
[!] WARNING: crashed: in/ok
Getting coverage for 'in/ok'
-- Program output begins --
qemu: uncaught target signal 6 (Aborted) - core dumped
-- Program output ends --

+++ Program killed by signal 6 +++
[!] WARNING: crashed: in/ok
[+] Processed 7 input files.
[+] Captured 1 tuples (map size 65536, highest value 5, total values 1611) in '.traces'.
make: *** [Makefile:19: musl-x86_64-run-bad] Error 2
```
