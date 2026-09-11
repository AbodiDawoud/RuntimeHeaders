#import "RuntimeInvocationBridge.h"
#import <objc/runtime.h>
#include <stdbool.h>
#include <string.h>

static NSError *RIError(NSString *message) {
    return [NSError errorWithDomain:@"RuntimeInspectorKit.Invocation" code:1
                          userInfo:@{NSLocalizedDescriptionKey: message}];
}

static const char *RIType(const char *encoding) {
    while (*encoding && strchr("rnNoORV", *encoding)) encoding++;
    return encoding;
}

static BOOL RIIsFamily(SEL selector, const char *family) {
    const char *name = sel_getName(selector);
    while (*name == '_') name++;
    size_t length = strlen(family);
    return strncmp(name, family, length) == 0 &&
        !(name[length] >= 'a' && name[length] <= 'z');
}

NSError *RIInvoke(id receiver, SEL selector, NSArray *arguments, id __autoreleasing *result) {
    *result = nil;
    // Keep ownership outside @try so normal returns from @catch release it too.
    NSMethodSignature *signature = nil;
    NSMutableString *callTypes = nil;
    NSInvocation *invocation = nil;
    @try {
        Method method = class_getInstanceMethod(object_getClass(receiver), selector);
        if (!method) return RIError(@"Method is unavailable.");
        signature = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
        if (signature.numberOfArguments != arguments.count + 2 || arguments.count > 3) {
            return RIError(@"The method's argument count does not match.");
        }
        // Initializers consume self and must only run on a freshly allocated object.
        if (RIIsFamily(selector, "init") || RIIsFamily(selector, "alloc")) {
            return RIError(@"Use instance creation for allocation and initialization.");
        }
        const char *returnType = RIType(signature.methodReturnType);
        if (!*returnType || !strchr("v@BsiqlSIQLfd", *returnType)) {
            return RIError(@"Unsupported return type.");
        }

        // Apple ARM64 callers must extend narrow integer arguments to 32 bits.
        // NSInvocation otherwise zero-extends negative shorts in optimized callees.
        callTypes = [NSMutableString stringWithFormat:@"%s@:", signature.methodReturnType];
        for (NSUInteger index = 2; index < signature.numberOfArguments; index++) {
            const char *type = RIType([signature getArgumentTypeAtIndex:index]);
            [callTypes appendFormat:@"%s", *type == 's' ? "i" : (*type == 'S' || *type == 'B') ? "I" : type];
        }
        invocation = [NSInvocation invocationWithMethodSignature:
            [NSMethodSignature signatureWithObjCTypes:callTypes.UTF8String]];
        invocation.target = receiver;
        invocation.selector = selector;
        for (NSUInteger index = 0; index < arguments.count; index++) {
            id argument = arguments[index];
            const char *type = RIType([invocation.methodSignature getArgumentTypeAtIndex:index + 2]);
            if (*type != '@' && ![argument isKindOfClass:NSNumber.class]) {
                return RIError(@"Expected a numeric argument.");
            }
            switch (*type) {
#define RI_SET_SCALAR(code, type, accessor) \
    case code: { type value = [argument accessor]; \
        [invocation setArgument:&value atIndex:index + 2]; break; }
                RI_SET_SCALAR('i', int, intValue)
                // The legacy l/L encodings are 32-bit; 64-bit long uses q/Q.
                RI_SET_SCALAR('l', int, intValue)
                RI_SET_SCALAR('q', long long, longLongValue)
                RI_SET_SCALAR('I', unsigned int, unsignedIntValue)
                RI_SET_SCALAR('L', unsigned int, unsignedIntValue)
                RI_SET_SCALAR('Q', unsigned long long, unsignedLongLongValue)
                RI_SET_SCALAR('d', double, doubleValue)
#undef RI_SET_SCALAR
                case '@':
                    [invocation setArgument:&argument atIndex:index + 2];
                    break;
                default:
                    return RIError(@"Unsupported argument type.");
            }
        }
        [invocation retainArguments];
        [invocation invoke];

        switch (*returnType) {
#define RI_GET_SCALAR(code, type) \
    case code: { type value = 0; [invocation getReturnValue:&value]; \
        *result = @(value); break; }
            RI_GET_SCALAR('B', bool)
            RI_GET_SCALAR('s', short)
            RI_GET_SCALAR('i', int)
            RI_GET_SCALAR('l', int)
            RI_GET_SCALAR('q', long long)
            RI_GET_SCALAR('S', unsigned short)
            RI_GET_SCALAR('I', unsigned int)
            RI_GET_SCALAR('L', unsigned int)
            RI_GET_SCALAR('Q', unsigned long long)
            RI_GET_SCALAR('f', float)
            RI_GET_SCALAR('d', double)
#undef RI_GET_SCALAR
            case '@': {
                void *value = NULL;
                [invocation getReturnValue:&value];
                BOOL owned = RIIsFamily(selector, "new") || RIIsFamily(selector, "copy") ||
                    RIIsFamily(selector, "mutableCopy");
                *result = owned ? CFBridgingRelease(value) : (__bridge id)value;
                break;
            }
            case 'v':
                break;
        }
        return nil;
    } @catch (NSException *exception) {
        return RIError([NSString stringWithFormat:@"%@: %@", exception.name, exception.reason ?: @""]);
    }
}

NSError *RICreateInstance(Class targetClass, id __autoreleasing *result) {
    *result = nil;
    @try {
        *result = [[targetClass alloc] init];
        return nil;
    } @catch (NSException *exception) {
        return RIError([NSString stringWithFormat:@"%@: %@", exception.name, exception.reason ?: @""]);
    }
}
