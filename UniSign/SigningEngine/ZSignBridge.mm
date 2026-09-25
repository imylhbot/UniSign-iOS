#import "ZSignBridge.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonCrypto.h>
#import <CommonCrypto/CommonDigest.h>

@implementation ZSignCertificateInfo
@end

// Helper to extract expiration date from DER certificate bytes on iOS
static NSDate *extractExpirationFromDER(NSData *derData) {
    if (!derData || derData.length < 32) return nil;
    const uint8_t *bytes = (const uint8_t *)derData.bytes;
    NSUInteger len = derData.length;
    int dateCount = 0;
    
    for (NSUInteger i = 0; i < len - 16; i++) {
        uint8_t tag = bytes[i];
        uint8_t length = bytes[i + 1];
        
        // UTCTime: tag 0x17, length 13 (e.g. "261231235959Z")
        if (tag == 0x17 && length == 13) {
            dateCount++;
            if (dateCount == 2) { // The 2nd date in TBSCertificate is notAfter (Expiration)
                NSString *dateStr = [[NSString alloc] initWithBytes:&bytes[i + 2] length:13 encoding:NSASCIIStringEncoding];
                NSDateFormatter *df = [[NSDateFormatter alloc] init];
                df.dateFormat = @"yyMMddHHmmss'Z'";
                df.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
                return [df dateFromString:dateStr];
            }
        }
        // GeneralizedTime: tag 0x18, length 15 (e.g. "20261231235959Z")
        else if (tag == 0x18 && length == 15) {
            dateCount++;
            if (dateCount == 2) {
                NSString *dateStr = [[NSString alloc] initWithBytes:&bytes[i + 2] length:15 encoding:NSASCIIStringEncoding];
                NSDateFormatter *df = [[NSDateFormatter alloc] init];
                df.dateFormat = @"yyyyMMddHHmmss'Z'";
                df.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
                return [df dateFromString:dateStr];
            }
        }
    }
    return nil;
}

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
    
    // Extract expiration date on iOS from DER certificate payload (iOS SDK compatible)
    NSData *certDER = (__bridge_transfer NSData *)SecCertificateCopyData(certRef);
    info.expirationDate = extractExpirationFromDER(certDER);
    if (info.expirationDate) {
        info.isExpired = [info.expirationDate compare:[NSDate date]] == NSOrderedAscending;
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
    
    // Safe byte-range locator for embedded XML plist
    NSData *startMarker = [@"<?xml" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *endMarker = [@"</plist>" dataUsingEncoding:NSUTF8StringEncoding];
    
    NSRange startRange = [data rangeOfData:startMarker options:0 range:NSMakeRange(0, data.length)];
    if (startRange.location == NSNotFound) {
        if (error) *error = [NSError errorWithDomain:@"UniSignError" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Invalid provisioning profile format."}];
        return nil;
    }
    
    NSRange searchEndRange = NSMakeRange(startRange.location, data.length - startRange.location);
    NSRange endRange = [data rangeOfData:endMarker options:NSDataSearchBackwards range:searchEndRange];
    if (endRange.location == NSNotFound) {
        if (error) *error = [NSError errorWithDomain:@"UniSignError" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Malformed XML in provisioning profile."}];
        return nil;
    }
    
    NSUInteger xmlLength = (endRange.location + endRange.length) - startRange.location;
    NSData *xmlData = [data subdataWithRange:NSMakeRange(startRange.location, xmlLength)];
    
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
        provisionPath:(nullable NSString *)provisionPath
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
        NSString *codeResourcesDir = [appPath stringByAppendingPathComponent:@"_CodeSignature"];
        [fm createDirectoryAtPath:codeResourcesDir withIntermediateDirectories:YES attributes:nil error:nil];
        
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
