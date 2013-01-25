#!/usr/bin/env dtrace -Cs

/* tested on darwin */

#define AF_INET	2

typedef struct sockaddr_in {
	short sin_family;
	unsigned short sin_port;
	unsigned char a0;
	unsigned char a1;
	unsigned char a2;
	unsigned char a3;
} sockaddr_in_t;

syscall::connect:entry
#ifdef EXECNAME
/execname == EXECNAME/
#endif
{
	this->sin = (struct sockaddr_in *)copyin(arg1, sizeof(struct sockaddr_in));
	this->fd = arg0;
	trace("connect");
}

syscall::connect:return
/this->sin/
{
	printf("%s:%d -- %d.%d.%d.%d:%hu (ret=%d)", execname, this->fd,
			this->sin->a0,
			this->sin->a1,
			this->sin->a2,
			this->sin->a3,
			this->sin->sin_port,
			arg1);
}
