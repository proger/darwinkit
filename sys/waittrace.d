proc:::exec-success
/execname == EXECNAME/
{
	trace(execname);
	inf = pid;
}

syscall::mmap:return
/pid == inf/
{
	system(CMD);
	exit(0);
}
