#pragma D option quiet
#pragma D option switchrate=10hz

/*
 * deltas are in microseconds (1 us = 1/1000 ms)
 */

inline int af_unix = 1;		/* AF_UNIX defined in sys/socket.h */
inline int af_inet = 2;		/* AF_INET defined in bsd/sys/socket.h */
inline int af_inet6 = 30;	/* AF_INET6 defined in bsd/sys/socket.h */

#define NTOHS(X) ((((X) & 0xFF00) >> 8) | (((X) & 0xFF)) << 8)

/*
 * Convert an IPv4 address into a dotted quad decimal string.
 * Until the inet_ntoa() functions are available from DTrace, this is
 * converted using the existing strjoin() and lltostr().  It's done in
 * two parts to avoid exhausting DTrace registers in one line of code.
 */
#define INET_NTOA(ptrbuf, addrbuf1, addrbuf2, ADDR_PTR, ADDR_DEST) \
	(ptrbuf) = (uint8_t *)&(ADDR_PTR); \
	(addrbuf1) = strjoin(lltostr((ptrbuf)[0] + 0ULL), strjoin(".", strjoin(lltostr((ptrbuf)[1] + 0ULL), "."))); \
	(addrbuf2) = strjoin(lltostr((ptrbuf)[2] + 0ULL), strjoin(".", lltostr((ptrbuf)[3] + 0ULL))); \
	(ADDR_DEST) = strjoin((addrbuf1), (addrbuf2));

#define ADDR_CLEANUP() \
	self->family = 0; \
	self->address = 0; \
	self->port = 0; \
	self->start = 0;

#define STR(table, value) (table[value] != NULL ? table[value] : lltostr(value))
#define AF(x) STR(af, x)

dtrace:::BEGIN
{
	/* Add translations as desired from /usr/include/sys/errno.h */
	err[0]            = "ok";
	err[EINTR]        = "EINTR";
	err[EIO]          = "EIO";
	err[EACCES]       = "EACCES";
	err[ENETDOWN]     = "ENETDOWN";
	err[ENETUNREACH]  = "ENETUNREACH";
	err[ECONNRESET]   = "ECONNRESET";
	err[ECONNREFUSED] = "ECONNREFUSED";
	err[ETIMEDOUT]    = "ETIMEDOUT";
	err[EHOSTDOWN]    = "EHOSTDOWN";
	err[EHOSTUNREACH] = "EHOSTUNREACH";
	err[EINPROGRESS]  = "EINPROGRESS";

	af[-1]            = "UNDEFINED";
	af[af_unix]	  = "un";  
	af[af_inet]	  = "in4";
	af[af_inet6]	  = "in6";
}

dtrace:::ERROR
/arg4 == DTRACEFLT_UPRIV/
{
	printf("user fault: %s\n", execname);
}

syscall::connect*:entry
/arg1/
{
	/* assume this is sockaddr_in until we can examine family */
	this->s = (struct sockaddr_in *)copyin(arg1, sizeof(struct sockaddr_in));
	this->sa = arg1;

	self->address = "(unknown)";
	self->port = -1;
	self->start = timestamp;
	self->family = this->s->sin_family;
}

syscall::connect*:entry
/arg1 == 0/
{
	self->address = "(unknown)";
	self->port = -1;
	self->start = timestamp;
	self->family = -1;
}

syscall::connect*:entry
/self->family == af_inet/
{
	self->port = NTOHS(this->s->sin_port);
	INET_NTOA(this->a, this->addr1, this->addr2, this->s->sin_addr, self->address);

	/*
	printf("%-6d %-16s  INET %-16s %-5d\n", pid, execname, self->address, self->port);
	*/
}

syscall::connect*:entry
/self->family == af_inet6/
{
	this->s6 = (struct sockaddr_in6 *)copyin(this->sa, sizeof (struct sockaddr_in6));

	self->port = NTOHS(this->s6->sin6_port);
	self->address = "tracememd";
	tracemem((user_addr_t)&this->s6->sin6_addr, 128);

	/*
	printf("%-6d %-16s INET6 %-16s %-5d\n", pid, execname, self->address, self->port);
	*/
}

syscall::connect*:entry
/self->family == af_unix/
{
	this->sun = (struct sockaddr_un *)copyin(this->sa, sizeof(struct sockaddr_un));
	self->address = this->sun->sun_path;
}

syscall::connect*:return
/self->family == af_unix/
{
	this->delta = (timestamp - self->start) / 1000;
	printf("connect(un) %s(%d) %s %d %s\n", execname, pid, self->address, this->delta, STR(err, errno));

	ADDR_CLEANUP();
}

syscall::connect*:return
/self->family && self->family != af_unix/
{
	this->delta = (timestamp - self->start) / 1000;
	printf("connect(%s) %s(%d) %s:%d %d %s\n", AF(self->family), execname, pid, self->address, self->port, this->delta, STR(err, errno));

	ADDR_CLEANUP();
}

syscall::accept*:entry
{
	/* assume this is sockaddr_in until we can examine family */
	this->sa = arg1;
        self->start = timestamp;
}

syscall::accept*:return
{
	this->s = (struct sockaddr_in *)copyin(this->sa, sizeof(struct sockaddr_in));
	self->family = this->s->sin_family;

        this->delta = (timestamp - self->start) / 1000;
        this->errstr = err[errno] != NULL ? err[errno] : lltostr(errno);
}

syscall::accept*:return
/self->family == af_unix/
{
	this->sun = (struct sockaddr_un *)copyin(this->sa, sizeof(struct sockaddr_un));
	self->address = this->sun->sun_path;

	printf("accept(un) %s(%d) %s %d %s\n", execname, pid, self->address, this->delta, this->errstr);

	ADDR_CLEANUP();
}

syscall::accept*:return
/self->family != af_unix/
{
	/* TODO: sockaddr_in6 */

	self->port = NTOHS(this->s->sin_port);
	INET_NTOA(this->a, this->addr1, this->addr2, this->s->sin_addr, self->address);

	printf("accept(%s) %s(%d) %s:%d %d %s\n", AF(self->family), execname, pid,
	    self->address, self->port, this->delta, this->errstr);

	ADDR_CLEANUP();
}
