#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include "notification.provider.h"

static IMP original_NSNotificationCenter$$postNotificationName$_object$_;

void
NSNotificationCenter$$postNotificationName$_object$_(id self, SEL _cmd, NSString *name, id object)
{
    if (NSNOTIFICATIONCENTER_NOTIFICATION_POST_ENABLED()) {
        NSNOTIFICATIONCENTER_NOTIFICATION_POST([[name description] UTF8String]);
    }

	original_NSNotificationCenter$$postNotificationName$_object$_(self, _cmd, name, object);
}

void
notificationhook_do(void)
{
	Class class = objc_getClass("NSNotificationCenter");
	SEL selector = sel_getUid("postNotificationName:object:");

	Method method = class_getInstanceMethod(class, selector);
	original_NSNotificationCenter$$postNotificationName$_object$_ = method_getImplementation(method);
	method_setImplementation(method, (IMP)NSNotificationCenter$$postNotificationName$_object$_);
}
