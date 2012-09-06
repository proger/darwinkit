/*
    File:       MachPortDump.c
 
    Contains:   A program to dump the Mach ports for a process.
 
    Written by: DTS
 
    Copyright:  Copyright (c) 2004 by Apple Computer, Inc., All Rights Reserved.
 
    Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
                ("Apple") in consideration of your agreement to the following terms, and your
                use, installation, modification or redistribution of this Apple software
                constitutes acceptance of these terms.  If you do not agree with these terms,
                please do not use, install, modify or redistribute this Apple software.
 
                In consideration of your agreement to abide by the following terms, and subject
                to these terms, Apple grants you a personal, non-exclusive license, under Apple's
                copyrights in this original Apple software (the "Apple Software"), to use,
                reproduce, modify and redistribute the Apple Software, with or without
                modifications, in source and/or binary forms; provided that if you redistribute
                the Apple Software in its entirety and without modifications, you must retain
                this notice and the following text and disclaimers in all such redistributions of
                the Apple Software.  Neither the name, trademarks, service marks or logos of
                Apple Computer, Inc. may be used to endorse or promote products derived from the
                Apple Software without specific prior written permission from Apple.  Except as
                expressly stated in this notice, no other rights or licenses, express or implied,
                are granted by Apple herein, including but not limited to any patent rights that
                may be infringed by your derivative works or by other works in which the Apple
                Software may be incorporated.
 
                The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
                WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
                WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
                PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
                COMBINATION WITH YOUR PRODUCTS.
 
                IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
                CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
                GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
                ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
                OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
                (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
                ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
    Change History (most recent first):
 
$Log: MachPortDump.c,v $
Revision 1.1  2004/11/01 14:47:10  eskimo1
Initial revision
 
 
*/
 
/////////////////////////////////////////////////////////////////
 
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdbool.h>
#include <sys/sysctl.h>
 
#include <servers/bootstrap.h>
 
#include <mach/mach.h>
 
/////////////////////////////////////////////////////////////////
#pragma mark ***** Compatibility Note
 
// Apple strongly recommends that developers avoid using Mach APIs 
// directly.  Mach APIs represent the lowest-level interface to 
// the kernel, and thus they are the most likely to change (or 
// become unsupportable) as the kernel evolves.
//
// Apple strongly recommends that developers use high-level wrappers 
// around Mach APIs where possible.  For example, rather than use 
// Mach messages directly, you could use CFMessagePort.  You should 
// only use Mach APIs if there is no higher-level alternatively.
//
// This sample uses Mach APIs directly, and thus seems to contravene 
// the above recommendations.  However, this is justified by the last 
// sentence of the previous paragraph: the job this sample does, 
// displaying information about a Mach task's port right name space, 
// is only possible via the use of Mach APIs.
//
// It might make sense for you to copy the techniques used by 
// MachPortDump into your application, to help detect port right 
// leaks and so on.  However, I strongly recommend that you include 
// this code only in your debug build.
 
/////////////////////////////////////////////////////////////////
#pragma mark ***** The Code
 
static const char *gProgramName;
 
static void PrintPortSetMembers(mach_port_t taskSendRight, mach_port_name_t portSetName)
    // For a given Mach port set within a given task, print the members 
    // of the port set.
{
    kern_return_t           err;
    kern_return_t           junk;
    mach_port_name_array_t  memberNames;
    mach_msg_type_number_t  memberNamesCount;
    mach_msg_type_number_t  memberIndex;
 
    memberNames = NULL;
 
    // Get an array of members.
    
    err = mach_port_get_set_status(
        taskSendRight, 
        portSetName,
        &memberNames, 
        &memberNamesCount
    );
    
    // Iterate over the array, printing each one.  Note that we print 6 members to 
    // a line and we start every line except the second with enough spaces to 
    // account for the information that we print that's common to each type 
    // of output.
    
    if (err == KERN_SUCCESS) {
        fprintf(stdout, "    ");
        for (memberIndex = 0; memberIndex < memberNamesCount; memberIndex++) {
            if ( (memberIndex != 0) && (memberIndex % 6) == 0) {
                // 6 columns of (8 characters plus space)
                // plus DNR column (3 chars) plus space
                fprintf(stdout, "\n%*s    ", (6 * (8 + 1)) + 3 + 1, "");
            }
            fprintf(stdout, "%#8x ", memberNames[memberIndex]);
        }
    } else {
        fprintf(stdout, "??? ");
    }
 
    // Clean up.
    
    if (memberNames != NULL) {
        junk = vm_deallocate(mach_task_self(), (vm_address_t) memberNames, memberNamesCount * sizeof(*memberNames));
        assert(junk == KERN_SUCCESS);
    }
}
 
static void PrintPortReceiveStatus(mach_port_t taskSendRight, mach_port_name_t receiveRight)
    // Print information about the Mach receive right in the specified 
    // task.
{
    kern_return_t           err;
    mach_port_status_t      status;
    mach_msg_type_number_t  statusCount;
 
    // Get information about the the right.
    
    statusCount = MACH_PORT_RECEIVE_STATUS_COUNT;
    err = mach_port_get_attributes(
        taskSendRight, 
        receiveRight,
        MACH_PORT_RECEIVE_STATUS,
        (mach_port_info_t) &status,
        &statusCount
    );
    assert( (err != KERN_SUCCESS) || (statusCount == MACH_PORT_RECEIVE_STATUS_COUNT) );
    
    // Print it, as a group of flags followed by 6 columns of numbers, 
    // which are basically all counters.
    
    if (err == KERN_SUCCESS) {        
        fprintf(
            stdout, 
            "%c%c%c ", 
            (status.mps_nsrequest ? 'N' : '-'),
            (status.mps_pdrequest ? 'P' : '-'),
            (status.mps_srights   ? 'S' : '-')
        );
 
        fprintf(
            stdout, 
            "%8u %8u %8u %8u %8u %8u", 
            status.mps_seqno,
            status.mps_mscount,
            status.mps_qlimit,
            status.mps_msgcount,
            status.mps_sorights,
            status.mps_pset
        );
        // The kernel always sets mps_flags to 0, so we don't both printing it.
        assert(status.mps_flags == 0);
    } else {
        fprintf(
            stdout, 
            "??? %8s %8s %8s %8s %8s %8s",
            "???", "???", "???", "???", "???", "???"
        );
    }
}
 
static kern_return_t PrintProcessPortSpace(pid_t pid, bool verbose)
    // Prints port rights owned by the specified process.
{
    kern_return_t           err;
    kern_return_t           junk;
    mach_port_t             taskSendRight;
    mach_port_name_array_t  rightNames;
    mach_msg_type_number_t  rightNamesCount;
    mach_port_type_array_t  rightTypes;
    mach_msg_type_number_t  rightTypesCount;
    unsigned int            i;
    
    taskSendRight = MACH_PORT_NULL;
    rightNames    = NULL;
    rightTypes    = NULL;
    
    // Get the task control port for the process.
 
    err = task_for_pid(mach_task_self(), pid, &taskSendRight);
    if (err != KERN_SUCCESS) {
        fprintf(stderr, "%s: Could not attach to process %lld (%#08x).\n", gProgramName, (long long) pid, err);
    }
 
    // Get a snapshot of the port name space for the task.
    
    if (err == KERN_SUCCESS) {
        err = mach_port_names(taskSendRight, &rightNames, &rightNamesCount, &rightTypes, &rightTypesCount);
    }
    if (err == KERN_SUCCESS) {
        if ( rightNamesCount != rightTypesCount ) {
            fprintf(stderr, "%s: Count mismatch (%u/%u)\n", gProgramName, rightNamesCount, rightTypesCount);
            err = KERN_FAILURE;
        }
    }
    
    // Print that snapshot.
            
    if (err == KERN_SUCCESS) {
        fprintf(stdout, "    Name     Send  Receive SendOnce  PortSet DeadName DNR");
        if (verbose) {
            fprintf(stdout, " flg    seqno  mscount   qlimit msgcount sorights     pset");
        }
        fprintf(stdout, "\n");
        fprintf(stdout, "    ----     ----  ------- --------  ------- -------- ---");
        if (verbose) {
            fprintf(stdout, " ---    -----  -------   ------ -------- --------     ----");
        }
        fprintf(stdout, "\n");
 
        // For each name, print a reference count of each type of right.  If running 
        // verbose, print other information as well.
 
        for (i = 0; i < rightNamesCount; i++) {
            mach_port_right_t   right;
            
            // We print the right name in hex because it makes it easier to 
            // see the index and generation fields.  See <mach/port.h> for 
            // information about this.
 
            fprintf(stdout, "%#8x ", rightNames[i]);
 
            for (right = MACH_PORT_RIGHT_SEND; right <= MACH_PORT_RIGHT_DEAD_NAME; right++) {
                mach_port_urefs_t   refCount;
 
                // If the rightTypes for this name has the bit associated 
                // with this type of right set (that is, if the name 
                // references this type of right), get the name's reference 
                // for this right and print it.  Otherwise just print an 
                // empty string to keep the columns lined up.
                
                if (rightTypes[i] & MACH_PORT_TYPE(right)) {
                    
                    err = mach_port_get_refs(taskSendRight, rightNames[i], right, &refCount);
                    if (err == KERN_SUCCESS) {
                        fprintf(stdout, "%8d ", refCount);
                    } else {
                        fprintf(stdout, "%8s ", "???");
                    }
                } else {
                    fprintf(stdout, "%8s ", "");
                }
            }
            if ( rightTypes[i] & MACH_PORT_TYPE_DNREQUEST ) {
                fprintf(stdout, "yes ");
            } else {
                fprintf(stdout, "    ");
            }
            
            if (verbose) {
                if (rightTypes[i] & MACH_PORT_TYPE_PORT_SET) {
                    PrintPortSetMembers(taskSendRight, rightNames[i]);
                } else if (rightTypes[i] & MACH_PORT_TYPE_RECEIVE) {
                    PrintPortReceiveStatus(taskSendRight, rightNames[i]);
                }
            }
            fprintf(stdout, "\n");
        }
    }
    
    // Clean up.
    
    if (rightNames != NULL) {
        junk = vm_deallocate(mach_task_self(), (vm_address_t) rightNames, rightNamesCount * sizeof(*rightNames));
        assert(junk == KERN_SUCCESS);
    }
    if (rightTypes != NULL) {
        junk = vm_deallocate(mach_task_self(), (vm_address_t) rightTypes, rightTypesCount * sizeof(*rightTypes));
        assert(junk == KERN_SUCCESS);
    }
    if (taskSendRight != MACH_PORT_NULL) {
        junk = mach_port_deallocate(mach_task_self(), taskSendRight);
        assert(junk == KERN_SUCCESS);
    }
    
    return err;
}
 
typedef struct kinfo_proc kinfo_proc;
 
static int GetBSDProcessList(kinfo_proc **procList, size_t *procCount)
    // Returns a list of all BSD processes on the system.  This routine
    // allocates the list and puts it in *procList and a count of the
    // number of entries in *procCount.  You are responsible for freeing
    // this list (use "free" from System framework).
    // On success, the function returns 0.
    // On error, the function returns a BSD errno value.
{
    int                 err;
    kinfo_proc *        result;
    bool                done;
    static const int    name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    // Declaring name as const requires us to cast it when passing it to
    // sysctl because the prototype doesn't include the const modifier.
    size_t              length;
 
    assert( procList != NULL);
    assert(*procList == NULL);
    assert(procCount != NULL);
 
    *procCount = 0;
 
    // We start by calling sysctl with result == NULL and length == 0.
    // That will succeed, and set length to the appropriate length.
    // We then allocate a buffer of that size and call sysctl again
    // with that buffer.  If that succeeds, we're done.  If that fails
    // with ENOMEM, we have to throw away our buffer and loop.  Note
    // that the loop causes use to call sysctl with NULL again; this
    // is necessary because the ENOMEM failure case sets length to
    // the amount of data returned, not the amount of data that
    // could have been returned.
 
    result = NULL;
    done = false;
    do {
        assert(result == NULL);
 
        // Call sysctl with a NULL buffer.
 
        length = 0;
        err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                      NULL, &length,
                      NULL, 0);
        if (err == -1) {
            err = errno;
        }
 
        // Allocate an appropriately sized buffer based on the results
        // from the previous call.
 
        if (err == 0) {
            result = malloc(length);
            if (result == NULL) {
                err = ENOMEM;
            }
        }
 
        // Call sysctl again with the new buffer.  If we get an ENOMEM
        // error, toss away our buffer and start again.
 
        if (err == 0) {
            err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                          result, &length,
                          NULL, 0);
            if (err == -1) {
                err = errno;
            }
            if (err == 0) {
                done = true;
            } else if (err == ENOMEM) {
                assert(result != NULL);
                free(result);
                result = NULL;
                err = 0;
            }
        }
    } while (err == 0 && ! done);
 
    // Clean up and establish post conditions.
 
    if (err != 0 && result != NULL) {
        free(result);
        result = NULL;
    }
    *procList = result;
    if (err == 0) {
        *procCount = length / sizeof(kinfo_proc);
    }
 
    assert( (err == 0) == (*procList != NULL) );
 
    return err;
}
 
static int FindProcessByName(const char *processName, pid_t *pid)
    // Find the process that best matches processName and return 
    // its PID.  It first tries to find an exact match; if that fails 
    // it tries to find a substring match; if that fails it checks 
    // whether processName is a number and returns that as the PID.
    //
    // On entry, processName must not be NULL, and it must not be the 
    // empty string.  pid must not be NULL.
    // On success, *pid will be the process ID of the found process.
    // On error, *pid is undefined.
{
    int             err;
    int             foundCount;
    kinfo_proc *    processList;
    size_t          processCount;
    size_t          processIndex;
    
    assert(processName != NULL);
    assert(processName[0] != 0);            // needed for strstr to behave
    assert(pid != NULL);
    
    processList = NULL;
    
    foundCount = 0;
    
    // Get the list of all processes.
    
    err = GetBSDProcessList(&processList, &processCount);
    
    if (err == 0) {
 
        // Search for an exact match.
        
        for (processIndex = 0; processIndex < processCount; processIndex++) {
            if ( strcmp(processList[processIndex].kp_proc.p_comm, processName) == 0 ) {
                *pid = processList[processIndex].kp_proc.p_pid;
                foundCount = 1;
                break;
            }
        }
        
        // If that failed, search for a substring match.
        
        if (foundCount == 0) {
            for (processIndex = 0; processIndex < processCount; processIndex++) {
                if ( strstr(processList[processIndex].kp_proc.p_comm, processName) != NULL ) {
                    *pid = processList[processIndex].kp_proc.p_pid;
                    foundCount += 1;
                }
            }
        }
        
        // If we found more than 1, that's ambiguous and we error out.
        
        if (foundCount > 1) {
            fprintf(stderr, "%s: '%s' does not denote a unique process.\n", gProgramName, processName);
            err = EINVAL;
        }
    }
    
    // If still not found, try processName as a PID.
    
    if ( (err == 0) && (foundCount == 0) ) {
        char *    firstInvalid;
        
        *pid = (pid_t) strtol(processName, &firstInvalid, 10);
        if ( (processName[0] == 0) || (*firstInvalid != 0) ) {
            err = EINVAL;
        }
    }
 
    free(processList);
 
    return err;
}
 
static void PrintUsage(void)
{
    fprintf(stderr, "usage: %s [options] [ [ pid | name ]... ]\n", gProgramName);
    fprintf(stderr, "       Send, Receive, SendOnce, PortSet, DeadName = right reference counts\n");
    fprintf(stderr, "       DNR = dead name request\n");
    fprintf(stderr, "       -w wide output, with lots of extra info\n");
    fprintf(stderr, "          flg      = N (no senders) P (port dead) S (send rights)\n");
    fprintf(stderr, "          seqno    = sequence number\n");
    fprintf(stderr, "          mscount  = make-send count\n");
    fprintf(stderr, "          qlimit   = queue limit\n");
    fprintf(stderr, "          msgcount = message count\n");
    fprintf(stderr, "          sorights = send-once right count\n");
    fprintf(stderr, "          pset     = port set count\n");
}
 
int main(int argc, char * argv[]) 
{
    kern_return_t       err;
    bool                verbose;
    int                 ch;
    int                 argIndex;
    
    // Set gProgramName to the last path component of argv[0]
    
    gProgramName = strrchr(argv[0], '/');
    if (gProgramName == NULL) {
        gProgramName = argv[0];
    } else {
        gProgramName += 1;
    }
    
    // Parse our options.
 
    verbose = false;
    do {
        ch = getopt(argc, argv, "w");
        if (ch != -1) {
            switch (ch) {
                case 'w':
                    verbose = true;
                    break;
                case '?':
                default:
                    PrintUsage();
                    exit(EXIT_FAILURE);
                    break;
            }
        }
    } while (ch != -1);
    
    // Handle the remaining arguments.  If none, we work against ourselves. 
    // Otherwise each string is treated as a process name, and we look that 
    // up using FindProcessByName.
    
    if (argv[optind] == NULL) {
        err = PrintProcessPortSpace(getpid(), verbose);
    } else {
        for (argIndex = optind; argIndex < argc; argIndex++) {
            pid_t   pid;
 
            if (argIndex > optind) {
                fprintf(stdout, "\n");
            }
            if (argv[argIndex][0] == 0) {
                err = EINVAL;
            } else {
                err = FindProcessByName(argv[argIndex], &pid);
            }
            if (err == 0) {
                fprintf(stdout, "Mach ports for '%s' (%lld):\n", argv[argIndex], (long long) pid);
                fprintf(stdout, "\n");
 
                err = PrintProcessPortSpace(pid, verbose);
            }
            
            if (err != 0) {
                break;
            }
        }
    }
    
    if (err != 0) {
        fprintf(stderr, "%s: Failed with error %d.\n", gProgramName, err);
    }
    return (err == 0) ? EXIT_SUCCESS : EXIT_FAILURE;
}
