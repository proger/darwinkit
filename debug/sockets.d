#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option switchrate=10hz

inline int af_unix = 1;		/* AF_UNIX defined in sys/socket.h */
inline int af_inet = 2;		/* AF_INET defined in bsd/sys/socket.h */
inline int af_inet6 = 30;	/* AF_INET6 defined in bsd/sys/socket.h */

dtrace:::BEGIN
{
	/* Add translations as desired from /usr/include/sys/errno.h */
	err[0]            = "Success";
	err[EINTR]        = "Interrupted syscall";
	err[EIO]          = "I/O error";
	err[EACCES]       = "Permission denied";
	err[ENETDOWN]     = "Network is down";
	err[ENETUNREACH]  = "Network unreachable";
	err[ECONNRESET]   = "Connection reset";
	err[ECONNREFUSED] = "Connection refused";
	err[ETIMEDOUT]    = "Timed out";
	err[EHOSTDOWN]    = "Host down";
	err[EHOSTUNREACH] = "No route to host";
	err[EINPROGRESS]  = "In progress";

	af[af_unix]	  = "un";
	af[af_inet]	  = "in4";
	af[af_inet6]	  = "in6";
}

syscall::connect*:entry
{
	/* assume this is sockaddr_in until we can examine family */
	this->s = (struct sockaddr_in *)copyin(arg1, sizeof(struct sockaddr));
	this->f = this->s->sin_family;
	this->sa = arg1;
	/*
	printf("fd: %d, family: %d\n", arg0, this->s->sin_family);
	*/
}

syscall::connect*:entry
/this->f == af_inet/
{
	self->family = this->f;

	/* Convert port to host byte order without ntohs() being available. */
	self->port = (this->s->sin_port & 0xFF00) >> 8;
	self->port |= (this->s->sin_port & 0xFF) << 8;

	/*
	 * Convert an IPv4 address into a dotted quad decimal string.
	 * Until the inet_ntoa() functions are available from DTrace, this is
	 * converted using the existing strjoin() and lltostr().  It's done in
	 * two parts to avoid exhausting DTrace registers in one line of code.
	 */
	this->a = (uint8_t *)&this->s->sin_addr;
	this->addr1 = strjoin(lltostr(this->a[0] + 0ULL), strjoin(".",
	    strjoin(lltostr(this->a[1] + 0ULL), ".")));
	this->addr2 = strjoin(lltostr(this->a[2] + 0ULL), strjoin(".",
	    lltostr(this->a[3] + 0ULL)));
	self->address = strjoin(this->addr1, this->addr2);

	self->start = timestamp;
	/*
	printf("%-6d %-16s  INET %-16s %-5d\n", pid, execname,
	    self->address, self->port);
	   */
}

syscall::connect*:entry
/this->f == af_inet6/
{
	self->family = this->f;
	this->s6 = (struct sockaddr_in6 *)copyin(this->sa, sizeof (struct sockaddr_in6));

	/* Convert port to host byte order without ntohs() being available. */
	self->port = (this->s6->sin6_port & 0xFF00) >> 8;
	self->port |= (this->s6->sin6_port & 0xFF) << 8;

	self->address = "tracememd";
	tracemem((user_addr_t)&this->s6->sin6_addr, 128);

	self->start = timestamp;
	/*
	printf("%-6d %-16s INET6 %-16s %-5d\n", pid, execname,
	    self->address, self->port);
	   */
}

syscall::connect*:entry
/this->f == af_unix/
{
	self->family = this->f;
	this->sun =  (struct sockaddr_un *)copyin(this->sa, sizeof(struct sockaddr_un));
	self->address = this->sun->sun_path;
	self->port = -1;

	self->start = timestamp;
/*
	printf("%-6d %-16s  UNIX %-16s      \n", pid, execname,
	    self->address);
*/
}

syscall::connect*:return
/self->start/
{
	this->delta = (timestamp - self->start) / 1000;
	this->errstr = err[errno] != NULL ? err[errno] : lltostr(errno);
	printf("connect(%s) %s(%d) %s:%d %d %s\n", af[self->family], execname, pid,
	    self->address, self->port, this->delta, this->errstr);
	self->family = 0;
	self->address = 0;
	self->port = 0;
	self->start = 0;
}


syscall::accept*:entry
{
	/* assume this is sockaddr_in until we can examine family */
	this->sa = arg1;
	/*
	printf("fd: %d, family: %d\n", arg0, this->s->sin_family);
	*/
}

syscall::accept*:return
{
	this->s = (struct sockaddr_in *)copyin(this->sa, sizeof(struct sockaddr));
	this->f = this->s->sin_family;
}

syscall::accept*:return
/this->f == af_unix/
{
	self->family = this->f;
	this->sun =  (struct sockaddr_un *)copyin(this->sa, sizeof(struct sockaddr_un));
	self->address = this->sun->sun_path;
	self->port = -1;
}

syscall::accept*:return
/self->family/
{
	this->delta = (timestamp - self->start) / 1000;
	this->errstr = err[errno] != NULL ? err[errno] : lltostr(errno);
	printf("accept(%s) %s(%d) %s:%d %d %s\n", af[self->family], execname, pid,
	    self->address, self->port, this->delta, this->errstr);
	self->start = 0;
	self->family = 0;
}

