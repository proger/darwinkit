#!/usr/sbin/dtrace I. -Cs

#include "dtrace_objc.h"

#if 1
objc$target::*postNotification*:entry
{
	@[cfstring(arg2)] = count();
}

tick-1s
{
	printa(@);
	trunc(@);
}

#endif

#if 0
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
#endif
