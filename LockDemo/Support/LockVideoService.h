#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LockSDKSupport.h"

NS_ASSUME_NONNULL_BEGIN

/// 视频 / 拍照门锁：P2P 预览、对讲、远程开关锁、强制上锁、重新拍照、成员密码。
@interface LockVideoService : NSObject

@property (nonatomic, readonly) NSString *devId;
@property (nonatomic, readonly) UIView *videoView;
@property (nonatomic, readonly) BOOL isCameraAvailable;

@property (nonatomic, copy, nullable) void (^onPreviewStateChanged)(BOOL previewing, NSString * _Nullable message);
@property (nonatomic, copy, nullable) void (^onTalkStateChanged)(BOOL talking);
@property (nonatomic, copy, nullable) void (^onRemoteUnlockRequest)(NSInteger seconds);
@property (nonatomic, copy, nullable) void (^onAlarmRequest)(NSInteger seconds);
@property (nonatomic, copy, nullable) void (^onForceLockReport)(void);
@property (nonatomic, copy, nullable) void (^onOperationMessage)(NSString *message);

- (instancetype)initWithDevId:(NSString *)devId;

- (void)connectAndStartPreview;
- (void)stopPreview;
- (void)disconnect;

- (BOOL)isPreviewOn;
- (BOOL)isP2PConnected;
- (void)setMuted:(BOOL)muted;
- (BOOL)isMuted;
- (void)startTalk;
- (void)stopTalk;
- (BOOL)isTalking;
- (BOOL)isTalkSupported;

- (void)remoteLockOpen:(BOOL)open
               confirm:(BOOL)confirm
               success:(LockVoidBlock)success
               failure:(LockErrorBlock)failure;

- (void)enforceLock:(BOOL)lock
            success:(LockVoidBlock)success
            failure:(LockErrorBlock)failure;

- (void)reTakePhoto:(BOOL)retake
            success:(LockVoidBlock)success
            failure:(LockErrorBlock)failure;

- (void)addPasswordForMember:(NSString *)userId
                  lockUserId:(NSInteger)lockUserId
                    userType:(NSInteger)userType
                        name:(NSString *)name
                    password:(NSString *)password
                     success:(LockVoidBlock)success
                     failure:(LockErrorBlock)failure;

@end

NS_ASSUME_NONNULL_END
