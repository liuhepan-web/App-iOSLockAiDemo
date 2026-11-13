#import <Foundation/Foundation.h>
#import "LockSDKSupport.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LockWiFiPairingMode) {
    LockWiFiPairingModeEZ = 0,
    LockWiFiPairingModeAP = 1,
    LockWiFiPairingModeQRCode = 2
};

/// EZ / AP / 二维码 / 蓝牙配网。
@interface LockPairingService : NSObject

@property (nonatomic, copy, nullable) void (^onProgress)(NSString *message);
@property (nonatomic, copy, nullable) void (^onSuccess)(NSDictionary<NSString *, id> *device);
@property (nonatomic, copy, nullable) void (^onFailure)(NSString *message);

@property (nonatomic, copy, nullable) void (^onBLEDeviceFound)(NSDictionary<NSString *, id> *device);

- (void)fetchPairingTokenWithHomeId:(long long)homeId
                            success:(LockStringBlock)success
                            failure:(LockErrorBlock)failure;

- (void)startWifiPairingWithMode:(LockWiFiPairingMode)mode
                          homeId:(long long)homeId
                            ssid:(NSString *)ssid
                        password:(NSString *)password
                         timeout:(NSTimeInterval)timeout;

- (void)startPairingWithToken:(NSString *)token
                         mode:(LockWiFiPairingMode)mode
                         ssid:(NSString *)ssid
                     password:(NSString *)password
                      timeout:(NSTimeInterval)timeout;

/// 二维码配网时，手机需要先展示二维码，设备扫码后再由手机侧启动激活。
- (void)startQRCodePairingWithToken:(NSString *)token
                               ssid:(NSString *)ssid
                           password:(NSString *)password
                            timeout:(NSTimeInterval)timeout;

- (void)stopWifiPairing;

- (void)startBLEScan;
- (void)stopBLEScan;
- (BOOL)isBluetoothPoweredOn;
- (void)activateBLEDeviceWithUUID:(NSString *)uuid
                           homeId:(long long)homeId
                          success:(LockResultBlock)success
                          failure:(LockErrorBlock)failure;

@end

NS_ASSUME_NONNULL_END
