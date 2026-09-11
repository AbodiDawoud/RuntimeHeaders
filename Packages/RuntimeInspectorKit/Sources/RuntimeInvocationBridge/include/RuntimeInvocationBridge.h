#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// A nil result is a successful object/void return; errors are returned separately.
FOUNDATION_EXPORT NSError * _Nullable RIInvoke(
    id receiver, SEL selector, NSArray *arguments, id _Nullable __autoreleasing * _Nonnull result
);
FOUNDATION_EXPORT NSError * _Nullable RICreateInstance(
    Class targetClass, id _Nullable __autoreleasing * _Nonnull result
);

NS_ASSUME_NONNULL_END
