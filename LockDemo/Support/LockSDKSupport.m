#import "LockSDKSupport.h"

#import <ThingSmartHomeKit/ThingSmartKit.h>
#import <ThingSmartNetworkKit/ThingSmartSDK.h>
#import <ThingSmartNetworkKit/ThingSmartSDK+Log.h>
#import <ThingSmartBusinessExtensionKit/ThingSmartBusinessExtensionConfig.h>
#import <ThingSmartActivatorCoreKit/ThingSmartActivator.h>

static NSString *LockSafeString(id value) {
    if (!value || value == [NSNull null]) {
        return @"";
    }
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    return [value description];
}

@interface LockSDKSupport ()
+ (BOOL)isEmailAccount:(NSString *)account;
+ (NSDictionary *)normalizeHome:(ThingSmartHomeModel *)model;
+ (NSDictionary *)normalizeDevice:(ThingSmartDeviceModel *)model;
@end

@implementation LockSDKSupport

+ (BOOL)hasCredentials {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"LocalSecrets" ofType:@"plist"];
    if (!path) {
        return NO;
    }
    NSDictionary *secrets = [NSDictionary dictionaryWithContentsOfFile:path];
    NSString *appKey = LockSafeString(secrets[@"AppKey"]);
    NSString *secret = LockSafeString(secrets[@"AppSecret"]);
    return appKey.length > 0
        && secret.length > 0
        && ![appKey containsString:@"YOUR_"]
        && ![secret containsString:@"YOUR_"];
}

+ (BOOL)configureSDK {
    static BOOL configured = NO;
    if (configured) {
        return YES;
    }
    if (![self hasCredentials]) {
        return NO;
    }
    NSDictionary *secrets = [NSDictionary dictionaryWithContentsOfFile:
                             [[NSBundle mainBundle] pathForResource:@"LocalSecrets" ofType:@"plist"]];
    NSString *appKey = LockSafeString(secrets[@"AppKey"]);
    NSString *secret = LockSafeString(secrets[@"AppSecret"]);

    [ThingSmartSDK sharedInstance].debugMode = YES;
    [[ThingSmartSDK sharedInstance] startWithAppKey:appKey secretKey:secret];
    [ThingSmartBusinessExtensionConfig setupConfig];
    configured = YES;
    return YES;
}

+ (BOOL)isLoggedIn {
    return [ThingSmartUser sharedInstance].isLogin;
}

+ (NSDictionary *)currentUserInfo {
    ThingSmartUser *user = [ThingSmartUser sharedInstance];
    return @{
        @"uid": LockSafeString(user.uid),
        @"nickname": LockSafeString(user.nickname),
        @"userName": LockSafeString(user.userName),
        @"email": LockSafeString(user.email),
        @"phoneNumber": LockSafeString(user.phoneNumber),
        @"countryCode": LockSafeString(user.countryCode),
        @"isLogin": @(user.isLogin)
    };
}

+ (void)sendVerifyCodeWithAccount:(NSString *)account
                      countryCode:(NSString *)countryCode
                             type:(NSInteger)type
                          success:(LockVoidBlock)success
                          failure:(LockErrorBlock)failure {
    [[ThingSmartUser sharedInstance] sendVerifyCodeWithUserName:account
                                                    countryCode:countryCode
                                                           type:type
                                                        success:^{
        if (success) success();
    } failure:^(NSError *error) {
        if (failure) failure([self messageForError:error]);
    }];
}

+ (BOOL)isEmailAccount:(NSString *)account {
    return [account containsString:@"@"];
}

+ (void)loginWithAccount:(NSString *)account
             countryCode:(NSString *)countryCode
                password:(NSString *)password
                 success:(LockVoidBlock)success
                 failure:(LockErrorBlock)failure {
    ThingSmartUser *user = [ThingSmartUser sharedInstance];
    if ([self isEmailAccount:account]) {
        [user loginByEmail:countryCode email:account password:password success:^{
            if (success) success();
        } failure:^(NSError *error) {
            if (failure) failure([self messageForError:error]);
        }];
    } else {
        [user loginByPhone:countryCode phoneNumber:account password:password success:^{
            if (success) success();
        } failure:^(NSError *error) {
            if (failure) failure([self messageForError:error]);
        }];
    }
}

+ (void)registerWithAccount:(NSString *)account
                countryCode:(NSString *)countryCode
                   password:(NSString *)password
                       code:(NSString *)code
                    success:(LockVoidBlock)success
                    failure:(LockErrorBlock)failure {
    ThingSmartUser *user = [ThingSmartUser sharedInstance];
    if ([self isEmailAccount:account]) {
        [user registerByEmail:countryCode email:account password:password code:code success:^{
            if (success) success();
        } failure:^(NSError *error) {
            if (failure) failure([self messageForError:error]);
        }];
    } else {
        [user registerByPhone:countryCode phoneNumber:account password:password code:code success:^{
            if (success) success();
        } failure:^(NSError *error) {
            if (failure) failure([self messageForError:error]);
        }];
    }
}

+ (void)logoutWithSuccess:(LockVoidBlock)success failure:(LockErrorBlock)failure {
    [[ThingSmartUser sharedInstance] loginOut:^{
        if (success) success();
    } failure:^(NSError *error) {
        if (failure) failure([self messageForError:error]);
    }];
}

+ (NSDictionary *)normalizeHome:(ThingSmartHomeModel *)model {
    return @{
        @"homeId": @(model.homeId),
        @"name": LockSafeString(model.name),
        @"geoName": LockSafeString(model.geoName),
        @"role": @(model.role)
    };
}

+ (void)fetchHomesWithSuccess:(LockArrayBlock)success failure:(LockErrorBlock)failure {
    ThingSmartHomeManager *manager = [[ThingSmartHomeManager alloc] init];
    [manager getHomeListWithSuccess:^(NSArray<ThingSmartHomeModel *> *homes) {
        NSMutableArray *items = [NSMutableArray array];
        for (ThingSmartHomeModel *model in homes) {
            [items addObject:[self normalizeHome:model]];
        }
        if (success) success(items);
    } failure:^(NSError *error) {
        if (failure) failure([self messageForError:error]);
    }];
}

+ (void)createHomeWithName:(NSString *)name success:(LockResultBlock)success failure:(LockErrorBlock)failure {
    ThingSmartHomeManager *manager = [[ThingSmartHomeManager alloc] init];
    [manager addHomeWithName:name
                     geoName:@""
                       rooms:@[]
                    latitude:0
                   longitude:0
                     success:^(long long homeId) {
        if (success) success(@(homeId));
    } failure:^(NSError *error) {
        if (failure) failure([self messageForError:error]);
    }];
}

+ (void)fetchHomeInfoWithHomeId:(long long)homeId success:(LockDictionaryBlock)success failure:(LockErrorBlock)failure {
    ThingSmartHome *home = [ThingSmartHome homeWithHomeId:homeId];
    [home getHomeDataWithSuccess:^(ThingSmartHomeModel *homeModel) {
        if (success) success([self normalizeHome:homeModel]);
    } failure:^(NSError *error) {
        if (failure) failure([self messageForError:error]);
    }];
}

+ (NSString *)deviceKindForCategoryCode:(NSString *)categoryCode productId:(NSString *)productId {
    NSString *code = [LockSafeString(categoryCode) lowercaseString];
    NSString *product = [LockSafeString(productId) lowercaseString];
    NSString *value = code.length > 0 ? code : product;

    if ([value containsString:@"ble_ms"]
        || [value containsString:@"jtmspro_2b_2"]
        || [value containsString:@"ble_jtms"]
        || ([value containsString:@"ble"] && [value containsString:@"ms"])) {
        return @"ble";
    }
    if ([value containsString:@"videolock_1w_1"] || [value containsString:@"videolock"]) {
        return @"video";
    }
    if ([value containsString:@"wf_jtmspro"]) {
        return @"photo";
    }
    if ([value containsString:@"wf_jtms"]
        || [value containsString:@"wf_ms"]
        || ([value containsString:@"wf"] && [value containsString:@"ms"])) {
        return @"wifi";
    }
    if ([value containsString:@"ms"] || [value containsString:@"lock"] || [value containsString:@"jtms"]) {
        return @"wifi";
    }
    return @"unknown";
}

+ (NSDictionary *)normalizeDevice:(ThingSmartDeviceModel *)model {
    return @{
        @"devId": LockSafeString(model.devId),
        @"name": LockSafeString(model.name),
        @"categoryCode": LockSafeString(model.categoryCode),
        @"productId": LockSafeString(model.productId),
        @"iconUrl": LockSafeString(model.iconUrl),
        @"isOnline": @(model.isOnline),
        @"isShare": @(model.isShare),
        @"homeId": @(model.homeId),
        @"kind": [self deviceKindForCategoryCode:model.categoryCode productId:model.productId]
    };
}

+ (void)fetchDevicesWithHomeId:(long long)homeId success:(LockArrayBlock)success failure:(LockErrorBlock)failure {
    ThingSmartHome *home = [ThingSmartHome homeWithHomeId:homeId];
    [home getHomeDataWithSuccess:^(ThingSmartHomeModel *homeModel) {
        NSMutableArray *items = [NSMutableArray array];
        for (ThingSmartDeviceModel *model in home.deviceList) {
            [items addObject:[self normalizeDevice:model]];
        }
        if (success) success(items);
    } failure:^(NSError *error) {
        if (failure) failure([self messageForError:error]);
    }];
}

+ (void)fetchDeviceInfoWithDevId:(NSString *)devId success:(LockDictionaryBlock)success failure:(LockErrorBlock)failure {
    ThingSmartDevice *device = [ThingSmartDevice deviceWithDeviceId:devId];
    if (!device.deviceModel) {
        if (failure) failure(@"设备不存在或不属于当前家庭");
        return;
    }
    if (success) success([self normalizeDevice:device.deviceModel]);
}

+ (void)removeDeviceWithDevId:(NSString *)devId success:(LockVoidBlock)success failure:(LockErrorBlock)failure {
    ThingSmartDevice *device = [ThingSmartDevice deviceWithDeviceId:devId];
    if (!device) {
        if (failure) failure(@"设备不存在");
        return;
    }
    [device remove:^{
        if (success) success();
    } failure:^(NSError *error) {
        if (failure) failure([self messageForError:error]);
    }];
}

+ (NSString *)currentWifiSSID {
    NSString *ssid = [ThingSmartActivator currentWifiSSID];
    return ssid.length > 0 ? ssid : @"";
}

+ (NSString *)messageForError:(NSError *)error {
    if (!error) {
        return @"未知错误";
    }
    NSString *description = error.localizedDescription;
    if (description.length == 0) {
        description = @"操作失败";
    }
    return [NSString stringWithFormat:@"%@ (%ld)", description, (long)error.code];
}

@end
