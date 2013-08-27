proc:::create
{
	procs[pid] = timestamp;
	printf("%s pid %d ppid %d", execname, pid, ppid);
}

proc:::exec-success
{
	printf("%s pid %d ppid %d creation: %d us", execname, pid, ppid, (timestamp - procs[ppid]) / 1000);
}

proc:::exit
{
	printf("%s pid %d ppid %d lifetime: %d us", execname, pid, ppid, (timestamp - procs[ppid]) / 1000);
}
