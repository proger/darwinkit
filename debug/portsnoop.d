#!/usr/sbin/dtrace -Cs

#define OSX_10_7_4

#ifdef OSX_10_7_3
#define ipc_space_kernel (void *)0xffffff801341bf40 /* lookup in gdb */
#endif
#ifdef OSX_10_7_4
#define ipc_space_kernel (void *)0xffffff80115b9f40
#endif
#define space_comm(space) ((proc_t)space->is_task->bsd_info)->p_comm
#define	IO_BITS_ACTIVE	0x80000000

ipc_kmsg_send:entry
{
	//trace(execname);
	this->h = ((struct ipc_kmsg *)arg0)->ikm_header;
	this->localp = this->h->msgh_local_port;
	this->remotep = this->h->msgh_remote_port;
	this->rvalid = this->remotep->ip_object.io_bits & IO_BITS_ACTIVE;
	this->rspace = this->remotep->data.receiver;
}

/*
ipc_kmsg_send:entry
/this->rvalid != 0/
{
	this->rspace = this->remotep->data.receiver;
	printf("execname %s", execname);
	printf(" space %p", this->rspace);
	printf(" localp %p", this->localp);
	printf(" remotep %p", this->remotep);
}
*/

#if 0
#ifndef FILTER_COMM
ipc_kmsg_send:entry
/this->rspace != ipc_space_kernel/
{
	printf("%p -> %p (%s)", this->localp, this->remotep, space_comm(this->rspace));
}
#endif
#endif

ipc_kmsg_send:entry
/this->rspace == ipc_space_kernel
#ifdef FILTER_COMM
	&& execname == FILTER_COMM
#endif
/
{
	printf("%p -> %p (%s -> kernel)", this->localp, this->remotep, execname);
#if 0
	self->mon = 1;
#endif
}

#if 0
fbt::: /self->mon == 1/ {}

ipc_kmsg_send:return
/self->mon == 1/
{
	self->mon = 0;
}
#endif

ipc_kmsg_send:entry
/this->rvalid != 0 && this->rspace != ipc_space_kernel
	&& this->rspace->is_task == 0/
{
	printf("%s -> NULL TASK (space %p)", execname, this->rspace);
	/*
	stack();
	*/
}

ipc_kmsg_send:entry
/this->rvalid != 0 && this->rspace != ipc_space_kernel && this->rspace->is_task != 0
#ifdef FILTER_COMM
	&& (space_comm(this->rspace) == FILTER_COMM || execname == FILTER_COMM)
#endif
/
{
	printf("%p -> %p (%s -> %s)", this->localp, this->remotep, execname, space_comm(this->rspace));
	@[execname, this->localp, this->remotep, ustack()] = count();
}
