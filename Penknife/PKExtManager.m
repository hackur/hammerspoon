#import "PKExtManager.h"

@implementation PKExtManager

+ (PKExtManager*) sharedExtManager {
    static PKExtManager* sharedExtManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedExtManager = [[PKExtManager alloc] init];
    });
    return sharedExtManager;
}

- (void) setup {
    
}

- (NSArray*) availableExts {
    return nil;
}

- (NSArray*) installedExts {
    return nil;
}

- (NSArray*) allExts {
    return nil;
}

- (void) updateAvailableExts {
    
}

@end