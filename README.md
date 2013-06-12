darwinkit
=========

Darwin scripts toolbox: DTrace and GDB scripts, housekeeping stuff

## OSX DTrace gotchas

* there is no `progenyof` -- `mach_trace.d` has to track its children manually
* no core affinity -- unordered events (no `-x temporal` too, processes may migrate between cores, turn off `option quiet` to make sure)
    * workaround:

            # column 2 should print the elapsed execution time
            dtrace -x evaltime=exec -Cs sys/machtrace.d -c ./a.out | sort -n -k2

## launchd stuff

* [insecure.shell](launchd/insecure.shell.plist) -- helps you learn how screwed your launchd daemon/agent environment is
    * run client: `socat tcp-connect:localhost:12345 readline`
    * make sure you have `socat` installed at `/usr/local/bin`! (use homebrew)
