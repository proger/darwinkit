#!/usr/sbin/dtrace -Cs
#pragma D option quiet

/* assuming sizeof(long) == 4 */
#define cfstring(p) copyinstr(*(user_addr_t *)copyin(p + 8, 4))

objc$target::*addObserver?selector?name?*:entry
{
	printf("%d [%s %s] %s\n", tid, probemod, probefunc, cfstring(arg4));
	ustack();
}

objc$target::*postNotificationName?*:entry
{
	printf("%d [%s %s] %s\n", tid, probemod, probefunc, cfstring(arg2));
	ustack();
}

objc$target:__CFNotification:*initWithName?*:entry
{
	printf("%d [%s %s] %s\n", tid, probemod, probefunc, cfstring(arg2));
	ustack();
}
