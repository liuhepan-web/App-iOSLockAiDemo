#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LockSDKSupport.h"

NS_ASSUME_NONNULL_BEGIN

/// Wi-Fi / 视频 / 拍照门锁的通用能力：动态密码、临时密码、记录、成员。
@interface LockBaseService : NSObject

@property (nonatomic, readonly) NSString *devId;
@property (nonatomic, readonly) BOOL isOnline;

/// 设备端发起远程开锁请求时回调，seconds 为剩余处理秒数。
@property (nonatomic, copy, nullable) void (^onRemoteUnlockRequest)(NSInteger seconds);
@property (nonatomic, copy, nullable) void (^onOnlineChanged)(BOOL online);

- (instancetype)initWithDevId:(NSString *)devId;

#pragma mark - Password

- (void)fetchDynamicPasswordWithSuccess:(LockStringBlock)success failure:(LockErrorBlock)failure;

- (void)createTempPasswordWithName:(NSString *)name
                          password:(NSString *)password
                     effectiveDate:(NSDate *)effectiveDate
                       invalidDate:(NSDate *)invalidDate
                           success:(LockVoidBlock)success
                           failure:(LockErrorBlock)failure;

- (void)fetchTempPasswordsWithSuccess:(LockArrayBlock)success failure:(LockErrorBlock)failure;

- (void)deleteTempPasswordWithCode:(NSInteger)code
                           success:(LockVoidBlock)success
                           failure:(LockErrorBlock)failure;

#pragma mark - Video / photo temporary passwords

/// 视频门锁在线临时密码所需的硬件密码编号（SN）与对应 dpId。
- (void)fetchVideoTempPasswordSnWithSuccess:(LockDictionaryBlock)success
                                    failure:(LockErrorBlock)failure;

/// 拍照门锁在线临时密码列表。
- (void)fetchPhotoTempPasswordsWithSuccess:(LockArrayBlock)success
                                   failure:(LockErrorBlock)failure;

/// 视频门锁在线临时密码列表。
- (void)fetchVideoTempPasswordsWithSuccess:(LockArrayBlock)success
                                   failure:(LockErrorBlock)failure;

- (void)createPhotoTempPasswordWithName:(NSString *)name
                               password:(NSString *)password
                          effectiveDate:(NSDate *)effectiveDate
                            invalidDate:(NSDate *)invalidDate
                                success:(LockVoidBlock)success
                                failure:(LockErrorBlock)failure;

- (void)createVideoTempPasswordWithName:(NSString *)name
                               password:(NSString *)password
                                     sn:(NSInteger)sn
                          effectiveDate:(NSDate *)effectiveDate
                            invalidDate:(NSDate *)invalidDate
                                success:(LockVoidBlock)success
                                failure:(LockErrorBlock)failure;

/// 创建视频门锁离线临时密码，成功后返回云端生成的密码。
- (void)createVideoOfflinePasswordWithName:(NSString *)name
                             effectiveDate:(NSDate *)effectiveDate
                               invalidDate:(NSDate *)invalidDate
                                   success:(LockStringBlock)success
                                   failure:(LockErrorBlock)failure;

- (void)deletePhotoTempPasswordWithId:(NSInteger)pwdId
                              success:(LockVoidBlock)success
                              failure:(LockErrorBlock)failure;

- (void)deleteVideoTempPasswordWithId:(NSInteger)unlockBindingId
                              success:(LockVoidBlock)success
                              failure:(LockErrorBlock)failure;

#pragma mark - Records

- (void)fetchUnlockRecordsWithOffset:(NSInteger)offset
                               limit:(NSInteger)limit
                             success:(LockArrayBlock)success
                             failure:(LockErrorBlock)failure;

#pragma mark - Remote unlock

- (void)replyRemoteUnlock:(BOOL)open
                  success:(LockVoidBlock)success
                  failure:(LockErrorBlock)failure;

#pragma mark - Members

- (void)fetchMembersWithSuccess:(LockArrayBlock)success failure:(LockErrorBlock)failure;

/// Wi-Fi 门锁创建普通成员（不带账号邀请）。
- (void)createMemberWithName:(NSString *)name
                     success:(LockVoidBlock)success
                     failure:(LockErrorBlock)failure;

- (void)deleteMemberWithUserId:(NSString *)userId
                       success:(LockVoidBlock)success
                       failure:(LockErrorBlock)failure;

/// Wi-Fi 门锁给成员绑定一个已存在的密码编号（SN）。
- (void)addUnlockRelationWithMemberUserId:(NSString *)userId
                                       sn:(NSInteger)sn
                                  success:(LockVoidBlock)success
                                  failure:(LockErrorBlock)failure;

/// 返回成员已绑定的开锁方式摘要文本。
- (void)fetchUnlockSummaryWithUserId:(NSString *)userId
                             success:(LockStringBlock)success
                             failure:(LockErrorBlock)failure;

/// 视频 / 拍照门锁：面板成员列表、创建、删除与详情摘要。
- (void)fetchPanelMembersWithSuccess:(LockArrayBlock)success failure:(LockErrorBlock)failure;

- (void)createPanelMemberWithName:(NSString *)name
                          success:(LockVoidBlock)success
                          failure:(LockErrorBlock)failure;

- (void)deletePanelMemberWithUserId:(NSString *)userId
                            success:(LockVoidBlock)success
                            failure:(LockErrorBlock)failure;

- (void)fetchPanelUnlockSummaryWithUserId:(NSString *)userId
                                  success:(LockStringBlock)success
                                  failure:(LockErrorBlock)failure;

@end

NS_ASSUME_NONNULL_END
