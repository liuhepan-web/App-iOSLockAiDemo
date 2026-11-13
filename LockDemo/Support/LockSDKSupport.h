#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^LockVoidBlock)(void);
typedef void (^LockErrorBlock)(NSString *message);
typedef void (^LockResultBlock)(id _Nullable result);
typedef void (^LockDictionaryBlock)(NSDictionary<NSString *, id> *dictionary);
typedef void (^LockArrayBlock)(NSArray<NSDictionary<NSString *, id> *> *items);
typedef void (^LockStringBlock)(NSString *value);

/// SDK 启动、账号、家庭、设备的统一入口。
@interface LockSDKSupport : NSObject

/// 读取 LocalSecrets.plist 并启动 SDK。缺少 AppKey/AppSecret 时返回 NO。
+ (BOOL)configureSDK;
+ (BOOL)hasCredentials;
+ (BOOL)isLoggedIn;
+ (NSDictionary<NSString *, id> *)currentUserInfo;

+ (void)sendVerifyCodeWithAccount:(NSString *)account
                      countryCode:(NSString *)countryCode
                             type:(NSInteger)type
                          success:(LockVoidBlock)success
                          failure:(LockErrorBlock)failure;

+ (void)loginWithAccount:(NSString *)account
             countryCode:(NSString *)countryCode
                password:(NSString *)password
                 success:(LockVoidBlock)success
                 failure:(LockErrorBlock)failure;

+ (void)registerWithAccount:(NSString *)account
                countryCode:(NSString *)countryCode
                   password:(NSString *)password
                       code:(NSString *)code
                    success:(LockVoidBlock)success
                    failure:(LockErrorBlock)failure;

+ (void)logoutWithSuccess:(LockVoidBlock)success failure:(LockErrorBlock)failure;

+ (void)fetchHomesWithSuccess:(LockArrayBlock)success failure:(LockErrorBlock)failure;
+ (void)createHomeWithName:(NSString *)name success:(LockResultBlock)success failure:(LockErrorBlock)failure;
+ (void)fetchHomeInfoWithHomeId:(long long)homeId success:(LockDictionaryBlock)success failure:(LockErrorBlock)failure;
+ (void)fetchDevicesWithHomeId:(long long)homeId success:(LockArrayBlock)success failure:(LockErrorBlock)failure;
+ (void)fetchDeviceInfoWithDevId:(NSString *)devId success:(LockDictionaryBlock)success failure:(LockErrorBlock)failure;
+ (void)removeDeviceWithDevId:(NSString *)devId success:(LockVoidBlock)success failure:(LockErrorBlock)failure;

/// 当前 Wi-Fi 名（iOS 13+ 需要定位权限，失败时返回空字符串，允许用户手动填写）。
+ (NSString *)currentWifiSSID;

/// wifi / video / photo / ble / unknown
+ (NSString *)deviceKindForCategoryCode:(nullable NSString *)categoryCode
                             productId:(nullable NSString *)productId;

+ (NSString *)messageForError:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END
