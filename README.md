darwinkit
=========

Darwin scripts toolbox: DTrace and GDB scripts, housekeeping stuff

## OSX DTrace gotchas

* there is no `progenyof` -- `mach_trace.d` has to track its children manually
* unordered events due to DTrace having per-cpu buffers and threads migrating between cores;
    * OSX has no core affinity API
    * no `-x temporal` too ([what is temporal](https://github.com/illumos/illumos-gate/commit/e5803b76927480e8f9b67b22201c484ccf4c2bcf))
    * workaround for `machtrace.d`:

            # column 2 should print the elapsed execution time
            dtrace -x evaltime=exec -Cs sys/machtrace.d -c ./a.out | sort -n -k2

## launchd stuff

* [insecure.shell](launchd/insecure.shell.plist) -- helps you learn how screwed your launchd daemon/agent environment is
    * run client: `socat tcp-connect:localhost:12345 readline`
    * make sure you have `socat` installed at `/usr/local/bin`! (use homebrew)
