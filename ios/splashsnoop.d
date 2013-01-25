#!/usr/sbin/dtrace -s

syscall::open:entry
/execname == "SpringBoard" && strstr(copyinstr(arg0), "Default@2x.png") != 0/
{
	trace(copyinstr(arg0));
	ustack();
	stopped = pid;
	stop();
}

END /stopped != 0/ {
	pidresume(stopped);
}
