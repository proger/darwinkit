#!/usr/bin/env python

# lldb-run: because lldb -s is broken

import sys
sys.path.insert(0, '/System/Library/PrivateFrameworks/LLDB.framework/Resources/Python')

import os
from itertools import ifilter
import jinja2

pid = int(sys.argv[1])

import lldb

dbg = lldb.SBDebugger.Create()
dbg.SetAsync(False)

target = dbg.CreateTarget(None)

ci = dbg.GetCommandInterpreter()
cro = lldb.SBCommandReturnObject()

if pid > 0:
    listener = lldb.SBListener()
    errp = lldb.SBError()
    process = target.AttachToProcessWithID(listener, pid, errp)

    sys.stderr.write('attach: {}\n'.format(errp))

for command in ifilter(None, (l.strip() for l in sys.stdin.readlines())):
    comm = str(jinja2.Template(command).render(**os.environ))

    if pid > 0:
        ci.HandleCommand(comm, cro)
        sys.stderr.write('{}: <{}>\n'.format(comm, cro))
    else:
        sys.stderr.write('{}\n'.format(comm))

sys.exit(0)
