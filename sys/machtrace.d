#pragma D option quiet

/*
 * trace system calls together with mach traps
 */

/*
 * Command line arguments
 */
inline int OPT_follow    = 1;
inline int OPT_printid   = 1;
inline int OPT_relative  = 1;
inline int OPT_elapsed   = 1;
inline int OPT_cpu       = 0;
inline int OPT_counts    = 1;
inline int OPT_stack     = 0;

#ifdef EXECNAME
inline int OPT_name      = 1;
inline string NAME       = NAME;
#else
inline int OPT_name      = 0;
inline string NAME       = "";
#endif

inline int OPT_trace     = 0;
inline string TRACE      = "";

dtrace:::BEGIN
/$target/
{
	printf("tracing pid %d\n", $target);
}

dtrace:::BEGIN
{
       /* print header */
       /* OPT_printid  ? printf("%-8s  ","PID/LWP") : 1; */
       OPT_printid  ? printf("\t%-8s  ","PID/THRD") : 1;
       OPT_relative ? printf("%8s ","RELATIVE") : 1;
       OPT_elapsed  ? printf("%7s ","ELAPSD") : 1;
       OPT_cpu      ? printf("%6s ","CPU") : 1;
       printf("SYSCALL(args) \t\t = return\n");

       /* globals */
       trackedpid[pid] = 0;
       self->child = 0;
       this->type = 0;
}

/*
 * Syscalls that were started before DTrace attached
 */

syscall:::return,
mach_trap:::return
/!self->start && (pid == $target || ppid == $target)/
{
       self->code = errno == 0 ? "" : "Err#";

       printf("UNEXPECTED RETURN: %5d 0x%x %s %s(???)\t\t = %d errno = %d\n",
	      pid, tid, probeprov, probefunc ,(int)arg0,(int)errno);
       OPT_stack ? ustack()    : 1;
       OPT_stack ? trace("\n") : 1;
}

/*
 * Save syscall entry info
 */

/* MacOS X: notice first appearance of child from fork. Its parent
   fires syscall::*fork:return in the ususal way (see below) */
syscall:::entry
/OPT_follow && trackedpid[ppid] == -1 && 0 == self->child/
{
       /* set as child */
       self->child = 1;

       /* print output */
       self->code = errno == 0 ? "" : "Err#";
       /* OPT_printid  ? printf("%5d/%d:  ",pid,tid) : 1; */
       OPT_printid  ? printf("%5d/0x%x:  ",pid,tid) : 1;
       OPT_relative ? printf("%8d:  ",vtimestamp/1000) : 1;
       OPT_elapsed  ? printf("%7d:  ",0) : 1;
       OPT_cpu      ? printf("%6d ",0) : 1;
       printf("%s()\t\t = %d %s%d\n","fork",
           0,self->code,(int)errno);
}

/* MacOS X: notice first appearance of child and parent from vfork */
syscall:::entry
/OPT_follow && trackedpid[ppid] > 0 && 0 == self->child/
{
       /* set as child */
       this->vforking_tid = trackedpid[ppid];
       self->child = (this->vforking_tid == tid) ? 0 : 1;

       /* print output */
       self->code = errno == 0 ? "" : "Err#";
       /* OPT_printid  ? printf("%5d/%d:  ",pid,tid) : 1; */
       OPT_printid  ? printf("%5d/0x%x:  ",(this->vforking_tid == tid) ? ppid : pid,tid) : 1;
       OPT_relative ? printf("%8d:  ",vtimestamp/1000) : 1;
       OPT_elapsed  ? printf("%7d:  ",0) : 1;
       OPT_cpu      ? printf("%6d ",0) : 1;
       printf("%s()\t\t = %d %s%d\n","vfork",
           (this->vforking_tid == tid) ? pid : 0,self->code,(int)errno);
}

syscall:::entry,
mach_trap:::entry

/($target && pid == $target) ||
 (OPT_name && NAME == strstr(NAME, execname)) ||
 (OPT_name && execname == strstr(execname, NAME)) ||
 (self->child)/
{
       /* set start details */
       self->start = timestamp;
       self->vstart = vtimestamp;
       self->arg0 = arg0;
       self->arg1 = arg1;
       self->arg2 = arg2;

       /* count occurances */
       OPT_counts == 1 ? @Counts[probeprov, probefunc] = count() : 1;
}

syscall::select:entry,
syscall::mmap:entry,
syscall::pwrite:entry,
syscall::pread:entry
/($target && pid == $target) ||
 (OPT_name && NAME == strstr(NAME, execname)) ||
 (OPT_name && execname == strstr(execname, NAME)) ||
 (self->child)/
{
       self->arg3 = arg3;
       self->arg4 = arg4;
       self->arg5 = arg5;
}

/*
 * Follow children
 */
syscall::fork:entry
/OPT_follow && self->start/
{
       /* track this parent process */
       trackedpid[pid] = -1;
}

syscall::vfork:entry
/OPT_follow && self->start/
{
       /* track this parent process */
       trackedpid[pid] = tid;
}

/* syscall::rexit:entry */
syscall::exit:entry
{
       /* forget child */
       self->child = 0;
       trackedpid[pid] = 0;
}

/*
 * Check for syscall tracing
 */
syscall:::entry
/OPT_trace && probefunc != TRACE/
{
       /* drop info */
       self->start = 0;
       self->vstart = 0;
       self->arg0 = 0;
       self->arg1 = 0;
       self->arg2 = 0;
       self->arg3 = 0;
       self->arg4 = 0;
       self->arg5 = 0;
}

/*
 * Print return data
 */

/*
 * NOTE:
 *  The following code is written in an intentionally repetetive way.
 *  The first versions had no code redundancies, but performed badly during
 *  benchmarking. The priority here is speed, not cleverness. I know there
 *  are many obvious shortcuts to this code, Ive tried them. This style has
 *  shown in benchmarks to be the fastest (fewest probes, fewest actions).
 */

/* print 3 args, return as hex */
syscall::sigprocmask:return
/self->start/
{
       /* calculate elapsed time */
       this->elapsed = timestamp - self->start;
       self->start = 0;
       this->cpu = vtimestamp - self->vstart;
       self->vstart = 0;
       self->code = errno == 0 ? "" : "Err#";

       /* print optional fields */
       /* OPT_printid  ? printf("%5d/%d:  ",pid,tid) : 1; */
       OPT_printid  ? printf("%5d/0x%x:  ",pid,tid) : 1;
       OPT_relative ? printf("%8d ",vtimestamp/1000) : 1;
       OPT_elapsed  ? printf("%7d ",this->elapsed/1000) : 1;
       OPT_cpu ? printf("%6d ",this->cpu/1000) : 1;

       /* print main data */
       printf("%s(0x%X, 0x%X, 0x%X)\t\t = 0x%X %s%d\n",probefunc,
           (int)self->arg0,self->arg1,self->arg2,(int)arg0,
           self->code,(int)errno);
       OPT_stack ? ustack()    : 1;
       OPT_stack ? trace("\n") : 1;
       self->arg0 = 0;
       self->arg1 = 0;
       self->arg2 = 0;
}

/* print 3 args, arg0 as a string */
syscall::execve:return,
syscall::stat:return,
syscall::stat64:return,
syscall::lstat:return,
syscall::lstat64:return,
syscall::access:return,
syscall::mkdir:return,
syscall::chdir:return,
syscall::chroot:return,
syscall::getattrlist:return, /* XXX 5 arguments */
syscall::chown:return,
syscall::lchown:return,
syscall::chflags:return,
syscall::readlink:return,
syscall::utimes:return,
syscall::pathconf:return,
syscall::truncate:return,
syscall::getxattr:return,
syscall::setxattr:return,
syscall::removexattr:return,
syscall::unlink:return,
syscall::open:return,
syscall::open_nocancel:return
/self->start/
{
       /* calculate elapsed time */
       this->elapsed = timestamp - self->start;
       self->start = 0;
       this->cpu = vtimestamp - self->vstart;
       self->vstart = 0;
       self->code = errno == 0 ? "" : "Err#";

       /* print optional fields */
       /* OPT_printid  ? printf("%5d/%d:  ",pid,tid) : 1; */
       OPT_printid  ? printf("%5d/0x%x:  ",pid,tid) : 1;
       OPT_relative ? printf("%8d ",vtimestamp/1000) : 1;
       OPT_elapsed  ? printf("%7d ",this->elapsed/1000) : 1;
       OPT_cpu      ? printf("%6d ",this->cpu/1000) : 1;

       /* print main data */
       printf("%s(\"%S\", 0x%X, 0x%X)\t\t = %d %s%d\n",probefunc,
           copyinstr(self->arg0),self->arg1,self->arg2,(int)arg0,
           self->code,(int)errno);
       OPT_stack ? ustack()    : 1;
       OPT_stack ? trace("\n") : 1;
       self->arg0 = 0;
       self->arg1 = 0;
       self->arg2 = 0;
}

/* print 3 args, arg1 as a string */
syscall::write:return,
syscall::write_nocancel:return,
syscall::read:return,
syscall::read_nocancel:return
/self->start/
{
       /* calculate elapsed time */
       this->elapsed = timestamp - self->start;
       self->start = 0;
       this->cpu = vtimestamp - self->vstart;
       self->vstart = 0;
       self->code = errno == 0 ? "" : "Err#";

       /* print optional fields */
       /* OPT_printid  ? printf("%5d/%d:  ",pid,tid) : 1; */
       OPT_printid  ? printf("%5d/0x%x:  ",pid,tid) : 1;
       OPT_relative ? printf("%8d ",vtimestamp/1000) : 1;
       OPT_elapsed  ? printf("%7d ",this->elapsed/1000) : 1;
       OPT_cpu      ? printf("%6d ",this->cpu/1000) : 1;

       /* print main data */
       printf("%s(0x%X, \"%S\", 0x%X)\t\t = %d %s%d\n",probefunc,self->arg0,
           arg0 == -1 ? "" : stringof(copyin(self->arg1,arg0)),self->arg2,(int)arg0,
           self->code,(int)errno);
       OPT_stack ? ustack()    : 1;
       OPT_stack ? trace("\n") : 1;
       self->arg0 = 0;
       self->arg1 = 0;
       self->arg2 = 0;
}

/* print 2 args, arg0 and arg1 as strings */
syscall::rename:return,
syscall::symlink:return,
syscall::link:return
/self->start/
{
       /* calculate elapsed time */
       this->elapsed = timestamp - self->start;
       self->start = 0;
       this->cpu = vtimestamp - self->vstart;
       self->vstart = 0;
       self->code = errno == 0 ? "" : "Err#";

       /* print optional fields */
       /* OPT_printid  ? printf("%5d/%d:  ",pid,tid) : 1; */
       OPT_printid  ? printf("%5d/0x%x:  ",pid,tid) : 1;
       OPT_relative ? printf("%8d ",vtimestamp/1000) : 1;
       OPT_elapsed  ? printf("%7d ",this->elapsed/1000) : 1;
       OPT_cpu      ? printf("%6d ",this->cpu/1000) : 1;

       /* print main data */
       printf("%s(\"%S\", \"%S\")\t\t = %d %s%d\n",probefunc,
           copyinstr(self->arg0), copyinstr(self->arg1),
           (int)arg0,self->code,(int)errno);
       OPT_stack ? ustack()    : 1;
       OPT_stack ? trace("\n") : 1;
       self->arg0 = 0;
       self->arg1 = 0;
       self->arg2 = 0;
}

/* print 0 arg output */
syscall::*fork:return
/self->start/
{
       /* calculate elapsed time */
       this->elapsed = timestamp - self->start;
       self->start = 0;
       this->cpu = vtimestamp - self->vstart;
       self->vstart = 0;
       self->code = errno == 0 ? "" : "Err#";

       /* print optional fields */
       /* OPT_printid  ? printf("%5d/%d:  ",pid,tid) : 1; */
       OPT_printid  ? printf("%5d/0x%x:  ",pid,tid) : 1;
       OPT_relative ? printf("%8d ",vtimestamp/1000) : 1;
       OPT_elapsed  ? printf("%7d ",this->elapsed/1000) : 1;
       OPT_cpu      ? printf("%6d ",this->cpu/1000) : 1;

       /* print main data */
       printf("%s()\t\t = %d %s%d\n",probefunc,
           (int)arg0,self->code,(int)errno);
       OPT_stack ? ustack()    : 1;
       OPT_stack ? trace("\n") : 1;
       self->arg0 = 0;
       self->arg1 = 0;
       self->arg2 = 0;
}

/* print 1 arg output */
syscall::close:return,
syscall::close_nocancel:return
/self->start/
{
       /* calculate elapsed time */
       this->elapsed = timestamp - self->start;
       self->start = 0;
       this->cpu = vtimestamp - self->vstart;
       self->vstart = 0;
       self->code = errno == 0 ? "" : "Err#";

       /* print optional fields */
       /* OPT_printid  ? printf("%5d/%d:  ",pid,tid) : 1; */
       OPT_printid  ? printf("%5d/0x%x:  ",pid,tid) : 1;
       OPT_relative ? printf("%8d ",vtimestamp/1000) : 1;
       OPT_elapsed  ? printf("%7d ",this->elapsed/1000) : 1;
       OPT_cpu      ? printf("%6d ",this->cpu/1000) : 1;

       /* print main data */
       printf("%s(0x%X)\t\t = %d %s%d\n",probefunc,self->arg0,
           (int)arg0,self->code,(int)errno);
       OPT_stack ? ustack()    : 1;
       OPT_stack ? trace("\n") : 1;
       self->arg0 = 0;
       self->arg1 = 0;
       self->arg2 = 0;
}

/* print 2 arg output */
syscall::utimes:return,
syscall::munmap:return
/self->start/
{
       /* calculate elapsed time */
       this->elapsed = timestamp - self->start;
       self->start = 0;
       this->cpu = vtimestamp - self->vstart;
       self->vstart = 0;
       self->code = errno == 0 ? "" : "Err#";

       /* print optional fields */
       /* OPT_printid  ? printf("%5d/%d:  ",pid,tid) : 1; */
       OPT_printid  ? printf("%5d/0x%x:  ",pid,tid) : 1;
       OPT_relative ? printf("%8d ",vtimestamp/1000) : 1;
       OPT_elapsed  ? printf("%7d ",this->elapsed/1000) : 1;
       OPT_cpu      ? printf("%6d ",this->cpu/1000) : 1;

       /* print main data */
       printf("%s(0x%X, 0x%X)\t\t = %d %s%d\n",probefunc,self->arg0,
           self->arg1,(int)arg0,self->code,(int)errno);
       OPT_stack ? ustack()    : 1;
       OPT_stack ? trace("\n") : 1;
       self->arg0 = 0;
       self->arg1 = 0;
       self->arg2 = 0;
}

/* print pread/pwrite with 4 arguments */
syscall::pread*:return,
syscall::pwrite*:return
/self->start/
{
       /* calculate elapsed time */
       this->elapsed = timestamp - self->start;
       self->start = 0;
       this->cpu = vtimestamp - self->vstart;
       self->vstart = 0;
       self->code = errno == 0 ? "" : "Err#";

       /* print optional fields */
       /* OPT_printid  ? printf("%5d/%d:  ",pid,tid) : 1; */
       OPT_printid  ? printf("%5d/0x%x:  ",pid,tid) : 1;
       OPT_relative ? printf("%8d ",vtimestamp/1000) : 1;
       OPT_elapsed  ? printf("%7d ",this->elapsed/1000) : 1;
       OPT_cpu      ? printf("%6d ",this->cpu/1000) : 1;

       /* print main data */
       printf("%s(0x%X, \"%S\", 0x%X, 0x%X)\t\t = %d %s%d\n",probefunc,self->arg0,
           stringof(copyin(self->arg1,self->arg2)),self->arg2,self->arg3,(int)arg0,self->code,(int)errno);
       OPT_stack ? ustack()    : 1;
       OPT_stack ? trace("\n") : 1;
       self->arg0 = 0;
       self->arg1 = 0;
       self->arg2 = 0;
       self->arg3 = 0;
}

/* print select with 5 arguments */
syscall::select:return
/self->start/
{
       /* calculate elapsed time */
       this->elapsed = timestamp - self->start;
       self->start = 0;
       this->cpu = vtimestamp - self->vstart;
       self->vstart = 0;
       self->code = errno == 0 ? "" : "Err#";

       /* print optional fields */
       /* OPT_printid  ? printf("%5d/%d:  ",pid,tid) : 1; */
       OPT_printid  ? printf("%5d/0x%x:  ",pid,tid) : 1;
       OPT_relative ? printf("%8d ",vtimestamp/1000) : 1;
       OPT_elapsed  ? printf("%7d ",this->elapsed/1000) : 1;
       OPT_cpu      ? printf("%6d ",this->cpu/1000) : 1;

       /* print main data */
       printf("%s(0x%X, 0x%X, 0x%X, 0x%X, 0x%X)\t\t = %d %s%d\n",probefunc,self->arg0,
           self->arg1,self->arg2,self->arg3,self->arg4,(int)arg0,self->code,(int)errno);
       OPT_stack ? ustack()    : 1;
       OPT_stack ? trace("\n") : 1;
       self->arg0 = 0;
       self->arg1 = 0;
       self->arg2 = 0;
       self->arg3 = 0;
       self->arg4 = 0;
}

/* mmap has 6 arguments */
syscall::mmap:return
/self->start/
{
       /* calculate elapsed time */
       this->elapsed = timestamp - self->start;
       self->start = 0;
       this->cpu = vtimestamp - self->vstart;
       self->vstart = 0;
       self->code = errno == 0 ? "" : "Err#";

       /* print optional fields */
       /* OPT_printid  ? printf("%5d/%d:  ",pid,tid) : 1; */
       OPT_printid  ? printf("%5d/0x%x:  ",pid,tid) : 1;
       OPT_relative ? printf("%8d ",vtimestamp/1000) : 1;
       OPT_elapsed  ? printf("%7d ",this->elapsed/1000) : 1;
       OPT_cpu      ? printf("%6d ",this->cpu/1000) : 1;

       /* print main data */
       printf("%s(0x%X, 0x%X, 0x%X, 0x%X, 0x%X, 0x%X)\t\t = 0x%X %s%d\n",probefunc,self->arg0,
           self->arg1,self->arg2,self->arg3,self->arg4,self->arg5, (int)arg0,self->code,(int)errno);
       OPT_stack ? ustack()    : 1;
       OPT_stack ? trace("\n") : 1;
       self->arg0 = 0;
       self->arg1 = 0;
       self->arg2 = 0;
       self->arg3 = 0;
       self->arg4 = 0;
       self->arg5 = 0;
}

/* print 3 arg output - default */
syscall:::return,
mach_trap:::return
/self->start/
{
       /* calculate elapsed time */
       this->elapsed = timestamp - self->start;
       self->start = 0;
       this->cpu = vtimestamp - self->vstart;
       self->vstart = 0;
       self->code = errno == 0 ? "" : "Err#";

       /* print optional fields */
       /* OPT_printid  ? printf("%5d/%d:  ",pid,tid) : 1; */
       OPT_printid  ? printf("%5d/0x%x:  ",pid,tid) : 1;
       OPT_relative ? printf("%8d ",vtimestamp/1000) : 1;
       OPT_elapsed  ? printf("%7d ",this->elapsed/1000) : 1;
       OPT_cpu      ? printf("%6d ",this->cpu/1000) : 1;

       /* print main data */
       printf("%s %s(0x%X, 0x%X, 0x%X)\t\t = %d %s%d\n",probeprov,probefunc,self->arg0,
           self->arg1,self->arg2,(int)arg0,self->code,(int)errno);
       OPT_stack ? ustack()    : 1;
       OPT_stack ? trace("\n") : 1;
       self->arg0 = 0;
       self->arg1 = 0;
       self->arg2 = 0;
}

dtrace:::END
{
       OPT_counts == 1 ? printa(@Counts) : 1;
}
