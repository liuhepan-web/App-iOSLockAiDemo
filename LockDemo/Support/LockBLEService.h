#import <Foundation/Foundation.h>
#import "LockSDKSupport.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^LockBLEMembersBlock)(NSArray<NSDictionary<NSString *, id> *> *members, BOOL proDevice);
typedef void (^LockBLEMemberBlock)(NSDictionary<NSString *, id> * _Nullable member, NSString * _Nullable message);
typedef void (^LockBLEProBlock)(BOOL proDevice);

/// 蓝牙门锁：连接、开关锁、同步、成员、密码、记录。
@interface LockBLEService : NSObject

@property (nonatomic, readonly) NSString *devId;
@property (nonatomic, readonly) long long homeId;
@property (nonatomic, readonly) BOOL isProDevice;

- (instancetype)initWithDevId:(NSString *)devId homeId:(long long)homeId;

- (BOOL)isBLEConnected;
- (BOOL)isOnline;

- (void)autoConnect;
- (void)connectWithTimeout:(NSTimeInterval)timeout
                completion:(void (^)(BOOL connected, NSString *message))completion;

- (void)unlockWithSuccess:(LockVoidBlock)success failure:(LockErrorBlock)failure;
- (void)lockWithSuccess:(LockVoidBlock)success failure:(LockErrorBlock)failure;
- (void)remoteUnlockWithSuccess:(LockVoidBlock)success failure:(LockErrorBlock)failure;
- (void)remoteLockWithSuccess:(LockVoidBlock)success failure:(LockErrorBlock)failure;

- (void)syncDataWithSuccess:(LockVoidBlock)success failure:(LockErrorBlock)failure;
- (void)fetchDynamicPasswordWithSuccess:(LockStringBlock)success failure:(LockErrorBlock)failure;
- (void)fetchCurrentMemberWithCompletion:(LockBLEMemberBlock)completion;

#pragma mark - Members

- (void)detectProWithCompletion:(LockBLEProBlock)completion;
- (void)fetchMembersWithSuccess:(LockBLEMembersBlock)success failure:(LockErrorBlock)failure;

- (void)createProMemberWithName:(NSString *)name
                   countryCode:(NSString *)countryCode
                       account:(NSString *)account
                       success:(LockVoidBlock)success
                       failure:(LockErrorBlock)failure;

- (void)deleteMemberWithUserId:(NSString *)userId
                      userType:(NSInteger)userType
                       success:(LockVoidBlock)success
                       failure:(LockErrorBlock)failure;

- (void)addPasswordForMemberUserId:(NSString *)userId
                        lockUserId:(NSInteger)lockUserId
                          userType:(NSInteger)userType
                              name:(NSString *)name
                          password:(NSString *)password
                           success:(LockVoidBlock)success
                           failure:(LockErrorBlock)failure;

- (void)fetchUnlockSummaryWithUserId:(NSString *)userId
                             success:(LockStringBlock)success
                             failure:(LockErrorBlock)failure;

#pragma mark - Passwords

- (void)createOfflinePasswordWithName:(NSString *)name
                              success:(LockStringBlock)success
                              failure:(LockErrorBlock)failure;

- (void)createOnlinePasswordWithName:(NSString *)name
                            password:(NSString *)password
                             success:(LockStringBlock)success
                             failure:(LockErrorBlock)failure;

- (void)fetchPasswordsWithSuccess:(LockArrayBlock)success failure:(LockErrorBlock)failure;

#pragma mark - Records

- (void)fetchUnlockRecordsWithOffset:(NSInteger)offset
                               limit:(NSInteger)limit
                             success:(LockArrayBlock)success
                             failure:(LockErrorBlock)failure;

@end

NS_ASSUME_NONNULL_END
