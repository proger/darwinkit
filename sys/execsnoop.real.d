#!/usr/sbin/dtrace -Cs
#pragma D option quiet

fbt::__mac_execve:entry, fbt::posix_spawn:entry
{
	self->want_malloc = 1;
}

/*
 * First _MALLOC call inside execve/posix_spawn allocates memory
 * for struct image_params, which will later be used to store
 * pointers to copied in argv vector.
 *
 * We can't get this pointer from any of exec_* functions because
 * they are static and not exposed to fbt in the vanilla kernel.
 */

fbt::_MALLOC:return
/self->want_malloc == 1/
{
	self->imgp = (struct image_params *)arg1;
	self->want_malloc = 0;
}

/*
 * At this point we know that the ip_startargv and friends are
 * filled in.
 */

proc:::exec-success
{
	this->arglen = self->imgp->ip_endargv - self->imgp->ip_startargv;
	this->arg = self->imgp->ip_startargv;
	printf("[%d->%d] ", ppid, pid);
}

#define ITER() 		\
proc:::exec-success	\
/this->arglen > 0/	\
{			\
	printf("%s ", stringof(this->arg));			\
	this->arglen -= strlen(stringof(this->arg)) + 1;	\
	this->arg += strlen(stringof(this->arg)) + 1;		\
}

ITER()
ITER()
ITER()
ITER()
ITER()
ITER()
ITER()
ITER()
ITER()
ITER()
ITER()

proc:::exec-success
{
	printf("\n");
}
