
#pragma D option quiet
#pragma D option switchrate=10hz

/*
 * deltas are in microseconds (1 us = 1/1000 ms)
 */

inline int af_unix = 1;		/* AF_UNIX defined in sys/socket.h */
inline int af_inet = 2;		/* AF_INET defined in bsd/sys/socket.h */
inline int af_inet6 = 30;	/* AF_INET6 defined in bsd/sys/socket.h */

/*
 * OSX DTrace stubs
 */

#define NTOHS(X) ((((X) & 0xFF00) >> 8) | (((X) & 0xFF)) << 8)

/*
 * Convert an IPv4 address into a dotted quad decimal string.
 * Until the inet_ntoa() functions are available from DTrace, this is
 * converted using the existing strjoin() and lltostr().  It's done in
 * two parts to avoid exhausting DTrace registers in one line of code.
 */
#define INET_NTOA(ADDR_PTR, ADDR_DEST) \
        this->a = (uint8_t *)&(ADDR_PTR);		\
	this->addr1 = strjoin(lltostr(this->a[0] + 0ULL), strjoin(".", strjoin(lltostr(this->a[1] + 0ULL), "."))); \
	this->addr2 = strjoin(lltostr(this->a[2] + 0ULL), strjoin(".", lltostr(this->a[3] + 0ULL))); \
	(ADDR_DEST) = strjoin(this->addr1, this->addr2);

#define SOCKADDR_UN(P) \
	this->sun = (struct sockaddr_un *)P; \
	self->address = this->sun->sun_path; \
	self->port = 0;

#define SOCKADDR_IN(P) \
	this->sin = (struct sockaddr_in *)P; \
	INET_NTOA(this->sin->sin_addr, self->address); \
	self->port = NTOHS(this->sin->sin_port);

#ifndef IPV6_VERBOSE
#define SOCKADDR_IN6(P) \
	this->sin6 = (struct sockaddr_in6 *)P; \
	self->port = NTOHS(this->sin6->sin6_port); \
	self->address = self->port == 0 ? "::?" : "?";
#else
#define SOCKADDR_IN6(P) \
	this->sin6 = (struct sockaddr_in6 *)P; \
	self->port = NTOHS(this->sin6->sin6_port); \
	self->address = self->port == 0 ? "::?" : "tracememd"; \
        tracemem((user_addr_t)&this->sin6->sin6_addr, 16); 
#endif

#define ADDR_INIT(ptr, len)			\
	this->s = (struct sockaddr *)copyin(ptr, len); \
	self->address = "(unknown)"; \
	self->port = 0; \
	self->family = this->s->sa_family; \

#define ADDR_CLEANUP() \
	self->family = 0; \
	self->address = 0; \
	self->port = 0; \
	self->start = 0;

#define PRINT_UN() \
	this->delta = (timestamp - self->start) / 1000; \
	printf("%s(un) %s(%d) %s %d %s\n", probefunc, execname, pid, self->address, this->delta, STR(err, errno)); \
	ADDR_CLEANUP();	

#define PRINT() \
	this->delta = (timestamp - self->start) / 1000; \
	printf("%s(%s=%d) %s(%d) %s:%d %d %s\n", probefunc, AF(self->family), self->s, execname, pid, \
	       self->address, self->port, this->delta, STR(err, errno)); \
	ADDR_CLEANUP();

#define STR(table, value) (table[value] != NULL ? table[value] : lltostr(value))
#define AF(x) STR(af, x)
#define SOTYPE(x) STR(so_type, x)

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

	so_type[-1]       = "UNDEFINED";
	so_type[0]        = "UNDEFINED";
	so_type[1]	  = "stream";  
	so_type[2]	  = "dgram";
}

dtrace:::ERROR
/arg4 == DTRACEFLT_UPRIV/
{
	printf("user fault: %s\n", execname);
}

#define socket_syscall_genprobes(func, entry_ptr, entry_len)   \
	syscall::func:entry { self->s = arg0; ADDR_INIT(entry_ptr, entry_len); self->start = timestamp; } \
	syscall::func:entry /self->family == af_inet/ {SOCKADDR_IN(this->s);} \
	syscall::func:entry /self->family == af_inet6/ {SOCKADDR_IN6(this->s);} \
	syscall::func:entry /self->family == af_unix/ {SOCKADDR_UN(this->s);} \
	syscall::func:return /self->family == af_unix/ {PRINT_UN();}	\
	syscall::func:return /self->family/ {PRINT();}

socket_syscall_genprobes(connect*, arg1, arg2)
socket_syscall_genprobes(bind, arg1, arg2)

syscall::socket:entry
{
	self->family = arg0;
	self->so_type = arg1;
}

syscall::socket:return
/self->so_type/
{
	printf("%s(%s, %s) %s(%d) = %d\n", probefunc, AF(self->family), SOTYPE(self->so_type), execname, pid, arg1);
	self->so_type = 0;
	self->family = 0;
}

/*
 * accept(2) is special: sockaddrs are written between entry and return by the kernel
 */

syscall::accept*:entry
{
	self->sa = arg1; /* kernel will write here later */
	self->lenp = (user_addr_t)arg2;

        self->start = timestamp;
}

syscall::accept*:return
{
	this->len = *(socklen_t *)copyin(self->lenp, sizeof(socklen_t));
	ADDR_INIT(self->sa, this->len);
}

syscall::accept*:return
/self->family == af_unix/
{
	SOCKADDR_UN(this->s);
	PRINT_UN();
}

syscall::accept*:return
/self->family == af_inet6/
{
	SOCKADDR_IN6(this->s);
	PRINT();
}

syscall::accept*:return
/self->family == af_inet/
{
	SOCKADDR_IN(this->s);
	PRINT();
}

syscall::accept*:return /self->family/ {PRINT();} 
