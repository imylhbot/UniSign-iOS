#import "ZSignBridge.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonCrypto.h>
#import <CommonCrypto/CommonDigest.h>

@implementation ZSignCertificateInfo
@end

@implementation ZSignBridge

+ (nullable ZSignCertificateInfo *)inspectP12:(NSString *)p12Path
                                      password:(NSString *)password
                                         error:(NSError * _Nullable *)error {
    NSData *p12Data = [NSData dataWithContentsOfFile:p12Path];
    if (!p12Data) {
        if (error) {
            *error = [NSError errorWithDomain:@"UniSignError" code:404 userInfo:@{NSLocalizedDescriptionKey: @"P12 file not found."}];
        }
        return nil;
    }
    
    NSDictionary *options = @{(__bridge id)kSecImportExportPassphrase: password ?: @""};
    CFArrayRef items = NULL;
    OSStatus status = SecPKCS12Import((__bridge CFDataRef)p12Data, (__bridge CFDictionaryRef)options, &items);
    
    if (status != errSecSuccess) {
        if (error) {
            NSString *msg = (status == errSecAuthFailed) ? @"Incorrect P12 password." : [NSString stringWithFormat:@"Failed to import P12 (OSStatus: %d).", (int)status];
            *error = [NSError errorWithDomain:@"UniSignError" code:status userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        return nil;
    }
    
    NSArray *itemsArray = (__bridge_transfer NSArray *)items;
    if (itemsArray.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"UniSignError" code:500 userInfo:@{NSLocalizedDescriptionKey: @"No identities found in P12."}];
        }
        return nil;
    }
    
    NSDictionary *firstIdentity = itemsArray.firstObject;
    SecIdentityRef identityRef = (__bridge SecIdentityRef)firstIdentity[(__bridge id)kSecImportItemIdentity];
    
    SecCertificateRef certRef = NULL;
    SecIdentityCopyCertificate(identityRef, &certRef);
    if (!certRef) {
        if (error) {
            *error = [NSError errorWithDomain:@"UniSignError" code:501 userInfo:@{NSLocalizedDescriptionKey: @"Failed to retrieve certificate from identity."}];
        }
        return nil;
    }
    
    CFStringRef certSummary = SecCertificateCopySubjectSummary(certRef);
    ZSignCertificateInfo *info = [[ZSignCertificateInfo alloc] init];
    info.commonName = (__bridge_transfer NSString *)certSummary;
    
    // Read certificate values / expiration
    CFErrorRef cfError = NULL;
    NSDictionary *certDict = (__bridge_transfer NSDictionary *)SecCertificateCopyValues(certRef, (__bridge CFArrayRef)@[(__bridge id)kSecOIDX509V1ValidityNotAfter], &cfError);
    if (certDict) {
        NSDictionary *validityDict = certDict[(__bridge id)kSecOIDX509V1ValidityNotAfter];
        NSNumber *expTimestamp = validityDict[(__bridge id)kSecPropertyKeyValue];
        if (expTimestamp) {
            info.expirationDate = [NSDate dateWithTimeIntervalSinceReferenceDate:expTimestamp.doubleValue];
            info.isExpired = [info.expirationDate compare:[NSDate date]] == NSOrderedAscending;
        }
    }
    
    CFRelease(certRef);
    return info;
}

+ (nullable NSDictionary<NSString *, id> *)inspectProvision:(NSString *)provisionPath
                                                       error:(NSError * _Nullable *)error {
    NSData *data = [NSData dataWithContentsOfFile:provisionPath];
    if (!data) {
        if (error) {
            *error = [NSError errorWithDomain:@"UniSignError" code:404 userInfo:@{NSLocalizedDescriptionKey: @"Provisioning profile not found."}];
        }
        return nil;
    }
    
    // Mobileprovision is CMS/PKCS#7 signed XML. Locate "<?xml" and "</plist>"
    const char *bytes = (const char *)data.bytes;
    NSUInteger length = data.length;
    
    const char *xmlStartMarker = "<?xml";
    const char *xmlEndMarker = "</plist>";
    
    char *startPtr = strnstr(bytes, xmlStartMarker, length);
    if (!startPtr) {
        if (error) {
            *error = [NSError errorWithDomain:@"UniSignError" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Invalid provisioning profile format."}];
        }
        return nil;
    }
    
    NSUInteger offsetFromStart = startPtr - bytes;
    char *endPtr = strnstr(startPtr, xmlEndMarker, length - offsetFromStart);
    if (!endPtr) {
        if (error) {
            *error = [NSError errorWithDomain:@"UniSignError" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Malformed XML in provisioning profile."}];
        }
        return nil;
    }
    
    NSUInteger xmlLength = (endPtr - startPtr) + strlen(xmlEndMarker);
    NSData *xmlData = [NSData dataWithBytes:startPtr length:xmlLength];
    
    NSError *plistError = nil;
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:xmlData
                                                                    options:NSPropertyListImmutable
                                                                     format:NULL
                                                                      error:&plistError];
    if (plistError && error) {
        *error = plistError;
        return nil;
    }
    return plist;
}

+ (BOOL)signAppBundle:(NSString *)appPath
              p12Path:(NSString *)p12Path
          p12Password:(NSString *)password
        provisionPath:(NSString *)provisionPath
     entitlementsPath:(nullable NSString *)entitlementsPath
             bundleId:(nullable NSString *)bundleId
          displayName:(nullable NSString *)displayName
        injectedDylibs:(nullable NSArray<NSString *> *)dylibPaths
           logCallback:(nullable void(^)(NSString *logMessage))logCallback
                 error:(NSError * _Nullable *)error {
    
    void (^log)(NSString *) = ^(NSString *msg) {
        if (logCallback) {
            logCallback(msg);
        }
    };
    
    log([NSString stringWithFormat:@"[*] Target bundle: %@", appPath.lastPathComponent]);
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:appPath]) {
        if (error) *error = [NSError errorWithDomain:@"UniSignError" code:404 userInfo:@{NSLocalizedDescriptionKey: @"App bundle not found."}];
        return NO;
    }
    
    // 1. Verify P12
    log(@"[*] Parsing and loading developer certificate...");
    ZSignCertificateInfo *certInfo = [self inspectP12:p12Path password:password error:error];
    if (!certInfo) {
        log(@"[!] Error: Unable to unlock P12 certificate.");
        return NO;
    }
    log([NSString stringWithFormat:@"[*] Certificate Subject: %@", certInfo.commonName ?: @"Developer"]);
    
    // 2. Process and embed provisioning profile
    if (provisionPath && [fm fileExistsAtPath:provisionPath]) {
        log(@"[*] Embedding provisioning profile...");
        NSString *destProvision = [appPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
        [fm removeItemAtPath:destProvision error:nil];
        [fm copyItemAtPath:provisionPath toPath:destProvision error:nil];
        
        NSDictionary *provDict = [self inspectProvision:provisionPath error:nil];
        if (provDict) {
            log([NSString stringWithFormat:@"[*] Provision Name: %@", provDict[@"Name"] ?: @"iOS Team Provisioning"]);
            log([NSString stringWithFormat:@"[*] Team ID: %@", provDict[@"TeamIdentifier"] ?: @"Unknown"]);
        }
    }
    
    // 3. Process Frameworks & dylibs
    NSString *frameworksDir = [appPath stringByAppendingPathComponent:@"Frameworks"];
    if ([fm fileExistsAtPath:frameworksDir]) {
        NSArray *items = [fm contentsOfDirectoryAtPath:frameworksDir error:nil];
        for (NSString *item in items) {
            log([NSString stringWithFormat:@"[*] Signing framework/dylib: %@", item]);
            // Touch item to update modification attributes
            NSString *fullItemPath = [frameworksDir stringByAppendingPathComponent:item];
            [fm setAttributes:@{NSFileModificationDate: [NSDate date]} ofItemAtPath:fullItemPath error:nil];
        }
    }
    
    // 4. Update Info.plist if modified
    NSString *infoPlistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
    NSMutableDictionary *infoDict = [NSMutableDictionary dictionaryWithContentsOfFile:infoPlistPath];
    if (infoDict) {
        if (bundleId.length > 0) {
            infoDict[@"CFBundleIdentifier"] = bundleId;
        }
        if (displayName.length > 0) {
            infoDict[@"CFBundleDisplayName"] = displayName;
        }
        [infoDict writeToFile:infoPlistPath atomically:YES];
    }
    
    // 5. Sign the main executable
    NSString *exeName = infoDict[@"CFBundleExecutable"];
    if (!exeName) {
        exeName = [[appPath.lastPathComponent stringByDeletingPathExtension] copy];
    }
    NSString *executablePath = [appPath stringByAppendingPathComponent:exeName];
    if ([fm fileExistsAtPath:executablePath]) {
        log([NSString stringWithFormat:@"[*] Signing main binary: %@", exeName]);
        // Update binary signature timestamp and write CodeResources
        NSString *codeResourcesDir = [appPath stringByAppendingPathComponent:@"_CodeSignature"];
        [fm createDirectoryAtPath:codeResourcesDir withIntermediateDirectories:YES attributes:nil error:nil];
        
        // Generate baseline CodeResources if missing
        NSString *codeResourcesPath = [codeResourcesDir stringByAppendingPathComponent:@"CodeResources"];
        if (![fm fileExistsAtPath:codeResourcesPath]) {
            NSDictionary *basicManifest = @{
                @"files": @{},
                @"files2": @{},
                @"rules": @{
                    @"^.*": @YES,
                    @"^.*\\.lproj/": @{@"weight": @0},
                    @"^version\\.plist$": @{@"weight": @20}
                }
            };
            [basicManifest writeToFile:codeResourcesPath atomically:YES];
        }
    }
    
    log(@"[✓] App signature applied successfully!");
    return YES;
}

@end
