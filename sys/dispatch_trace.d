#!/usr/sbin/dtrace -Z -s

/*
 * Copyright (c) 2010-2011 Apple Inc. All rights reserved.
 * Copyright (c) 2013 Vladimir Kirillov <proger@hackndev.com>
 *
 * @APPLE_APACHE_LICENSE_HEADER_START@
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @APPLE_APACHE_LICENSE_HEADER_END@
 */

/* 
 * Usage: dispatch_dtrace.d -p [pid]
 *        traced process must have been executed with
 *        DYLD_IMAGE_SUFFIX=_profile or DYLD_IMAGE_SUFFIX=_debug
 *
 *        _OR_
 *
 *        mv -v /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator7.0.sdk/usr/lib/system/libdispatch.dylib{,.backup}
 *        cp -v /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator7.0.sdk/usr/lib/system/{introspection/,}libdispatch.dylib
 */

#pragma D option quiet
#pragma D option bufsize=16m

BEGIN {
	printf("%-8s %-3s %-8s   %-35s%-15s%-?s   %-43s%-?s   %-14s%-?s    %s\n",
		"Time us", "CPU", "Thread", "Function", "Probe", "Queue", "Label",
		"Item", "Kind", "Context", "Symbol");
}

dispatch$target:::queue-push,
dispatch$target:::queue-push,
dispatch$target:::queue-pop,
dispatch$target:::queue-pop,
dispatch$target:::callout-entry,
dispatch$target:::callout-entry,
dispatch$target:::callout-return,
dispatch$target:::callout-return /!start/ {
	start = walltimestamp;
}

/* probe queue-push/-pop(dispatch_queue_t queue, const char *label,
 *         dispatch_object_t item, const char *kind,
 *         dispatch_function_t function, void *context)
 */
dispatch$target:::queue-push,
dispatch$target:::queue-push,
dispatch$target:::queue-pop,
dispatch$target:::queue-pop {
	printf("%-8d %-3d 0x%08p %-35s%-15s0x%0?p %-43s0x%0?p %-14s0x%0?p",
		(walltimestamp-start)/1000, cpu, tid, probefunc, probename, arg0,
		copyinstr(arg1, 42), arg2, copyinstr(arg3, 13), arg5);
	usym(arg4);
	printf("\n");
}

/* probe callout-entry/-return(dispatch_queue_t queue, const char *label,
 *         dispatch_function_t function, void *context)
 */
dispatch$target:::callout-entry,
dispatch$target:::callout-entry,
dispatch$target:::callout-return,
dispatch$target:::callout-return {
	printf("%-8d %-3d 0x%08p %-35s%-15s0x%0?p %-43s%-?s   %-14s0x%0?p",
		(walltimestamp-start)/1000, cpu, tid, probefunc, probename, arg0,
		copyinstr(arg1, 42), "", "", arg3);
	usym(arg2);
	printf("\n");
}
