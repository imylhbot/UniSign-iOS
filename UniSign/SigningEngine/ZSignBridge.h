#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZSignCertificateInfo : NSObject
@property (nonatomic, copy) NSString *commonName;
@property (nonatomic, copy) NSString *teamId;
@property (nonatomic, copy) NSString *teamName;
@property (nonatomic, strong) NSDate *expirationDate;
@property (nonatomic, assign) BOOL isExpired;
@end

@interface ZSignBridge : NSObject

/// Inspect and validate a PKCS#12 (.p12) certificate file
+ (nullable ZSignCertificateInfo *)inspectP12:(NSString *)p12Path
                                      password:(NSString *)password
                                         error:(NSError * _Nullable *)error;

/// Inspect and extract metadata from a .mobileprovision file
+ (nullable NSDictionary<NSString *, id> *)inspectProvision:(NSString *)provisionPath
                                                       error:(NSError * _Nullable *)error;

/// Execute code signing on an unzipped .app bundle
+ (BOOL)signAppBundle:(NSString *)appPath
              p12Path:(NSString *)p12Path
          p12Password:(NSString *)password
        provisionPath:(NSString *)provisionPath
     entitlementsPath:(nullable NSString *)entitlementsPath
             bundleId:(nullable NSString *)bundleId
          displayName:(nullable NSString *)displayName
        injectedDylibs:(nullable NSArray<NSString *> *)dylibPaths
           logCallback:(nullable void(^)(NSString *logMessage))logCallback
                 error:(NSError * _Nullable *)error;

@end

NS_ASSUME_NONNULL_END
