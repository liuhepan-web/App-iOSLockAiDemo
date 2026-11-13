#import "LockPairingService.h"

#import <ThingSmartHomeKit/ThingSmartKit.h>
#import <ThingSmartActivatorCoreKit/ThingSmartActivator.h>
#import <ThingSmartBLECoreKit/ThingSmartBLEManager.h>
#import <ThingSmartBLECoreKit/ThingBLEAdvModel.h>
#import <ThingSmartBLEKit/ThingSmartBLEManager+Biz.h>

static void LockMain(void (^block)(void)) {
    if (!block) return;
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

static NSString *LockPairString(id value) {
    if (!value || value == [NSNull null]) return @"";
    return [value isKindOfClass:[NSString class]] ? value : [value description];
}

@interface LockPairingService () <ThingSmartActivatorDelegate, ThingSmartBLEManagerDelegate>
@property (nonatomic, strong, nullable) ThingSmartActivator *activator;
@property (nonatomic, strong, nullable) ThingSmartBLEManager *bleManager;
@property (nonatomic, strong) NSMutableDictionary<NSString *, ThingBLEAdvModel *> *discoveredDevices;
@property (nonatomic, assign) BOOL sessionFinished;
@end

@implementation LockPairingService

- (instancetype)init {
    self = [super init];
    if (self) {
        _discoveredDevices = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc {
    [self.activator stopConfigWiFi];
    [self.bleManager stopListening:YES];
}

#pragma mark - WiFi pairing

- (ThingSmartActivator *)currentActivator {
    if (!self.activator) {
        self.activator = [[ThingSmartActivator alloc] init];
        self.activator.delegate = self;
    }
    return self.activator;
}

- (void)fetchPairingTokenWithHomeId:(long long)homeId
                            success:(LockStringBlock)success
                            failure:(LockErrorBlock)failure {
    [[self currentActivator] getTokenWithHomeId:homeId success:^(NSString *token) {
        LockMain(^{
            if (success) success(LockPairString(token));
        });
    } failure:^(NSError *error) {
        LockMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)startWifiPairingWithMode:(LockWiFiPairingMode)mode
                          homeId:(long long)homeId
                            ssid:(NSString *)ssid
                        password:(NSString *)password
                         timeout:(NSTimeInterval)timeout {
    self.sessionFinished = NO;
    LockMain(^{
        if (self.onProgress) self.onProgress(@"正在获取配网 Token…");
    });
    __weak typeof(self) weakSelf = self;
    [self fetchPairingTokenWithHomeId:homeId success:^(NSString *token) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self startPairingWithToken:token mode:mode ssid:ssid password:password timeout:timeout];
    } failure:^(NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.sessionFinished = YES;
        LockMain(^{
            if (self.onFailure) self.onFailure(message);
        });
    }];
}

- (void)startPairingWithToken:(NSString *)token
                         mode:(LockWiFiPairingMode)mode
                         ssid:(NSString *)ssid
                     password:(NSString *)password
                      timeout:(NSTimeInterval)timeout {
    self.sessionFinished = NO;
    ThingSmartActivator *activator = [self currentActivator];
    ThingActivatorMode sdkMode = ThingActivatorModeEZ;
    NSString *modeName = @"EZ";
    if (mode == LockWiFiPairingModeAP) {
        sdkMode = ThingActivatorModeAP;
        modeName = @"AP";
    } else if (mode == LockWiFiPairingModeQRCode) {
        sdkMode = ThingActivatorModeQRCode;
        modeName = @"二维码";
    }
    LockMain(^{
        if (self.onProgress) {
            self.onProgress([NSString stringWithFormat:@"已进入%@配网，等待设备上报…", modeName]);
        }
    });
    [activator startConfigWiFi:sdkMode
                         ssid:ssid
                     password:password
                        token:token
                      timeout:timeout > 0 ? timeout : 100];
}

- (void)startQRCodePairingWithToken:(NSString *)token
                               ssid:(NSString *)ssid
                           password:(NSString *)password
                            timeout:(NSTimeInterval)timeout {
    [self startPairingWithToken:token mode:LockWiFiPairingModeQRCode ssid:ssid password:password timeout:timeout];
}

- (void)stopWifiPairing {
    self.sessionFinished = YES;
    [self.activator stopConfigWiFi];
    self.activator.delegate = nil;
    self.activator = nil;
}

#pragma mark - ThingSmartActivatorDelegate

- (void)activator:(ThingSmartActivator *)activator didReceiveDevice:(ThingSmartDeviceModel *)deviceModel error:(NSError *)error {
    if (self.sessionFinished) return;
    if (error || !deviceModel) {
        self.sessionFinished = YES;
        NSString *message = error ? [LockSDKSupport messageForError:error] : @"配网失败，请重试";
        LockMain(^{
            if (self.onFailure) self.onFailure(message);
        });
        return;
    }
    self.sessionFinished = YES;
    NSDictionary *device = @{
        @"devId": LockPairString(deviceModel.devId),
        @"name": LockPairString(deviceModel.name),
        @"categoryCode": LockPairString(deviceModel.categoryCode),
        @"productId": LockPairString(deviceModel.productId),
        @"homeId": @(deviceModel.homeId),
        @"isOnline": @(deviceModel.isOnline),
        @"kind": [LockSDKSupport deviceKindForCategoryCode:deviceModel.categoryCode productId:deviceModel.productId]
    };
    [self.activator stopConfigWiFi];
    LockMain(^{
        if (self.onSuccess) self.onSuccess(device);
    });
}

- (void)activator:(ThingSmartActivator *)activator didReceiveDevice:(ThingSmartDeviceModel *)deviceModel step:(ThingActivatorStep)step error:(NSError *)error {
    if (self.sessionFinished) return;
    if (error) {
        self.sessionFinished = YES;
        LockMain(^{
            if (self.onFailure) self.onFailure([LockSDKSupport messageForError:error]);
        });
        return;
    }
    if (step == ThingActivatorStepTimeOut) {
        self.sessionFinished = YES;
        [activator stopConfigWiFi];
        LockMain(^{
            if (self.onFailure) self.onFailure(@"配网超时，请检查 Wi-Fi 名称与密码后重试");
        });
        return;
    }
    NSString *stepText = nil;
    switch (step) {
        case ThingActivatorStepFound:
            stepText = @"发现设备，正在连接…";
            break;
        case ThingActivatorStepRegisted:
            stepText = @"设备已注册，正在初始化…";
            break;
        case ThingActivatorStepIntialized:
            stepText = @"设备初始化完成";
            break;
        default:
            break;
    }
    if (stepText) {
        LockMain(^{
            if (self.onProgress) self.onProgress(stepText);
        });
    }
}

- (void)deviceStateError:(NSError *)error {
    if (self.sessionFinished) return;
    self.sessionFinished = YES;
    LockMain(^{
        if (self.onFailure) self.onFailure([LockSDKSupport messageForError:error]);
    });
}

#pragma mark - BLE pairing

- (ThingSmartBLEManager *)currentBLEManager {
    if (!self.bleManager) {
        self.bleManager = [ThingSmartBLEManager sharedInstance];
        self.bleManager.delegate = self;
    }
    return self.bleManager;
}

- (void)startBLEScan {
    [self.discoveredDevices removeAllObjects];
    ThingSmartBLEManager *manager = [self currentBLEManager];
    manager.delegate = self;
    [manager startListening:YES];
    LockMain(^{
        if (self.onProgress) self.onProgress(@"正在扫描附近可配网的蓝牙门锁…");
    });
}

- (void)stopBLEScan {
    [self.bleManager stopListening:YES];
}

- (BOOL)isBluetoothPoweredOn {
    return [self currentBLEManager].isPoweredOn;
}

- (void)didDiscoveryDeviceWithDeviceInfo:(ThingBLEAdvModel *)deviceInfo {
    if (!deviceInfo || deviceInfo.isActive) return;
    NSString *uuid = LockPairString(deviceInfo.uuid);
    if (uuid.length == 0) return;

    BOOL isNew = self.discoveredDevices[uuid] == nil;
    self.discoveredDevices[uuid] = deviceInfo;
    if (!isNew) return;

    NSDictionary *extra = [deviceInfo.extraParams isKindOfClass:[NSDictionary class]] ? deviceInfo.extraParams : @{};
    NSString *name = LockPairString(extra[@"name"]);
    if (name.length == 0) {
        name = LockPairString(deviceInfo.extraParams[@"devName"]);
    }
    if (name.length == 0) {
        name = @"蓝牙门锁";
    }
    NSDictionary *payload = @{
        @"uuid": uuid,
        @"productId": LockPairString(deviceInfo.productId),
        @"mac": LockPairString(deviceInfo.mac),
        @"name": name
    };
    LockMain(^{
        if (self.onBLEDeviceFound) self.onBLEDeviceFound(payload);
    });
}

- (void)activateBLEDeviceWithUUID:(NSString *)uuid
                           homeId:(long long)homeId
                          success:(LockResultBlock)success
                          failure:(LockErrorBlock)failure {
    ThingBLEAdvModel *deviceInfo = self.discoveredDevices[uuid];
    if (!deviceInfo) {
        if (failure) failure(@"未找到该蓝牙设备，请重新扫描");
        return;
    }
    [[self currentBLEManager] activeBLE:deviceInfo homeId:homeId success:^(ThingSmartDeviceModel *deviceModel) {
        [self.bleManager stopListening:YES];
        NSDictionary *payload = @{
            @"devId": LockPairString(deviceModel.devId),
            @"name": LockPairString(deviceModel.name),
            @"categoryCode": LockPairString(deviceModel.categoryCode),
            @"productId": LockPairString(deviceModel.productId),
            @"homeId": @(deviceModel.homeId),
            @"isOnline": @(deviceModel.isOnline),
            @"kind": [LockSDKSupport deviceKindForCategoryCode:deviceModel.categoryCode productId:deviceModel.productId]
        };
        LockMain(^{
            if (success) success(payload);
        });
    } failure:^{
        LockMain(^{
            if (failure) failure(@"蓝牙设备激活失败，请重试");
        });
    }];
}

@end
