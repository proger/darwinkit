#!/usr/bin/env dtrace -s

typedef struct sockaddr_in {
	short sin_family;
	unsigned short sin_port;
	unsigned char a0;
	unsigned char a1;
	unsigned char a2;
	unsigned char a3;
} sockaddr_in_t;

BEGIN
{
	afd["", 0] = 0;
}

syscall::accept*:entry
{
	self->sinaddr = arg1;
}

syscall::accept*:return
{
	this->sin = (struct sockaddr_in *)copyin(self->sinaddr, sizeof(struct sockaddr_in));
	printf("%s:%d -- %d.%d.%d.%d:%hu", execname, arg1,
			this->sin->a0,
			this->sin->a1,
			this->sin->a2,
			this->sin->a3,
			this->sin->sin_port);
	afd[execname, arg1] = 1;
}

syscall::close:entry
/afd[execname, arg0] == 1/
{
	printf("%s:%d", execname, arg0);
	afd[execname, arg0] = 0;
}
