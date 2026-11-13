#import "LockVideoService.h"

#import <ThingSmartLockKit/ThingSmartLockKit.h>

static void LockVideoMain(void (^block)(void)) {
    if (!block) return;
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@interface LockVideoService () <ThingSmartWiFiLockDeviceDelegate>
@property (nonatomic, strong) ThingSmartWiFiLockDevice *wifiDevice;
@property (nonatomic, copy) NSString *devId;
@property (nonatomic, strong) UIView *fallbackView;
@end

@implementation LockVideoService

- (instancetype)initWithDevId:(NSString *)devId {
    self = [super init];
    if (self) {
        _devId = [devId copy];
        _wifiDevice = [[ThingSmartWiFiLockDevice alloc] initWithDeviceId:devId];
        _wifiDevice.delegate = self;
        _fallbackView = [[UIView alloc] initWithFrame:CGRectZero];
        _fallbackView.backgroundColor = [UIColor blackColor];
    }
    return self;
}

- (UIView *)videoView {
    UIView *view = self.wifiDevice.cameraType.videoView;
    return view ?: self.fallbackView;
}

- (BOOL)isCameraAvailable {
    return self.wifiDevice.cameraType != nil;
}

#pragma mark - Preview

- (void)connectAndStartPreview {
    if (!self.isCameraAvailable) {
        LockVideoMain(^{
            if (self.onPreviewStateChanged) {
                self.onPreviewStateChanged(NO, @"当前设备不支持视频预览");
            }
        });
        return;
    }
    [self.wifiDevice p2pConnect];
    [self.wifiDevice startPreviewWithDefinition:ThingSmartCameraDefinitionHigh];
}

- (void)stopPreview {
    [self.wifiDevice stopPreview];
}

- (void)disconnect {
    [self.wifiDevice stopTalk];
    [self.wifiDevice stopPreview];
    [self.wifiDevice p2pDisConnect];
}

- (BOOL)isPreviewOn {
    return [self.wifiDevice isPreviewOn];
}

- (BOOL)isP2PConnected {
    return [self.wifiDevice isP2pConnected];
}

- (void)setMuted:(BOOL)muted {
    [self.wifiDevice enableMute:muted];
}

- (BOOL)isMuted {
    return [self.wifiDevice isMuting];
}

- (void)startTalk {
    [self.wifiDevice startTalk];
}

- (void)stopTalk {
    [self.wifiDevice stopTalk];
}

- (BOOL)isTalking {
    return [self.wifiDevice isTalking];
}

- (BOOL)isTalkSupported {
    return [self.wifiDevice isSupportedTalk];
}

#pragma mark - Lock operations

- (void)remoteLockOpen:(BOOL)open
               confirm:(BOOL)confirm
               success:(LockVoidBlock)success
               failure:(LockErrorBlock)failure {
    [self.wifiDevice remoteLockWithDevId:self.devId open:open confirm:confirm success:^(BOOL result) {
        LockVideoMain(^{
            if (!result) {
                if (failure) failure(open ? @"远程开锁失败" : @"远程关门失败");
                return;
            }
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockVideoMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)enforceLock:(BOOL)lock
            success:(LockVoidBlock)success
            failure:(LockErrorBlock)failure {
    [self.wifiDevice enforceLock:lock success:^{
        LockVideoMain(^{
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockVideoMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)reTakePhoto:(BOOL)retake
            success:(LockVoidBlock)success
            failure:(LockErrorBlock)failure {
    [self.wifiDevice reTakePhoto:retake success:^{
        LockVideoMain(^{
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockVideoMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

#pragma mark - Member password

- (void)addPasswordForMember:(NSString *)userId
                  lockUserId:(NSInteger)lockUserId
                    userType:(NSInteger)userType
                        name:(NSString *)name
                    password:(NSString *)password
                     success:(LockVoidBlock)success
                     failure:(LockErrorBlock)failure {
    if (password.length == 0) {
        if (failure) failure(@"请输入密码");
        return;
    }
    [self.wifiDevice addProUnlockOpModeForMemberWithDevice:userId
                                                   isAdmin:(userType == 1)
                                                lockUserId:(int)lockUserId
                                               unlockDpCode:@"unlock_password"
                                               unlockOpType:ThingUnlockOpTypePassword
                                                 unlockName:name
                                              effectiveDate:nil
                                                invalidDate:nil
                                                      times:0
                                                 dataLength:(int)password.length
                                                dataContent:password
                                                         sn:0
                                                    timeout:15
                                                    appSend:NO
                                                    success:^(id result) {
        LockVideoMain(^{
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockVideoMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

#pragma mark - ThingSmartWiFiLockDeviceDelegate

- (void)unlockRequestCountdown:(ThingSmartWiFiLockDevice *)device time:(NSInteger)time {
    LockVideoMain(^{
        if (self.onRemoteUnlockRequest) self.onRemoteUnlockRequest(time);
    });
}

- (void)alarmRequestCountdown:(ThingSmartWiFiLockDevice *)device time:(NSInteger)time {
    LockVideoMain(^{
        if (self.onAlarmRequest) self.onAlarmRequest(time);
    });
}

- (void)onForceLockUpReport:(ThingSmartWiFiLockDevice *)device {
    LockVideoMain(^{
        if (self.onForceLockReport) self.onForceLockReport();
    });
}

- (void)onRemoteUnlockReport:(ThingSmartWiFiLockDevice *)device {
    LockVideoMain(^{
        if (self.onOperationMessage) self.onOperationMessage(@"设备已执行远程开锁");
    });
}

- (void)onVideoRequestRealtime:(ThingSmartWiFiLockDevice *)device model:(NSString *)model {
    LockVideoMain(^{
        if (self.onOperationMessage) self.onOperationMessage(@"收到门铃呼叫，可打开实时画面");
    });
}

- (void)onLockMessageArrived:(ThingSmartWiFiLockDevice *)device message:(NSDictionary *)message {
    LockVideoMain(^{
        if (self.onOperationMessage) {
            self.onOperationMessage([NSString stringWithFormat:@"门锁消息：%@", message]);
        }
    });
}

- (void)device:(ThingSmartWiFiLockDevice *)device didReceiveAddOpMessage:(ThingSmartBLELockOpMessageModel *)opMessage {
    LockVideoMain(^{
        if (self.onOperationMessage) self.onOperationMessage(@"设备已新增开锁方式");
    });
}

- (void)device:(ThingSmartWiFiLockDevice *)device didReceiveDeleteOpMessage:(ThingSmartBLELockOpMessageModel *)opMessage {
    LockVideoMain(^{
        if (self.onOperationMessage) self.onOperationMessage(@"设备已删除开锁方式");
    });
}

#pragma mark - Camera delegate

- (void)cameraInitFailed:(ThingSmartCameraErrorCode)errorCode {
    LockVideoMain(^{
        if (self.onPreviewStateChanged) {
            self.onPreviewStateChanged(NO, [NSString stringWithFormat:@"摄像头初始化失败 (%ld)", (long)errorCode]);
        }
    });
}

- (void)cameraDidConnected:(id<ThingSmartCameraType>)camera {
    LockVideoMain(^{
        if (self.onPreviewStateChanged) self.onPreviewStateChanged(NO, @"视频通道已连接，正在加载画面…");
    });
}

- (void)cameraDidBeginPreview:(id<ThingSmartCameraType>)camera {
    LockVideoMain(^{
        if (self.onPreviewStateChanged) self.onPreviewStateChanged(YES, nil);
    });
}

- (void)cameraDidStopPreview:(id<ThingSmartCameraType>)camera {
    LockVideoMain(^{
        if (self.onPreviewStateChanged) self.onPreviewStateChanged(NO, @"预览已停止");
    });
}

- (void)cameraDisconnected:(id<ThingSmartCameraType>)camera specificErrorCode:(NSInteger)errorCode {
    LockVideoMain(^{
        if (self.onPreviewStateChanged) {
            self.onPreviewStateChanged(NO, [NSString stringWithFormat:@"视频连接断开 (%ld)", (long)errorCode]);
        }
    });
}

- (void)cameraDidBeginTalk:(id<ThingSmartCameraType>)camera {
    LockVideoMain(^{
        if (self.onTalkStateChanged) self.onTalkStateChanged(YES);
    });
}

- (void)cameraDidStopTalk:(id<ThingSmartCameraType>)camera {
    LockVideoMain(^{
        if (self.onTalkStateChanged) self.onTalkStateChanged(NO);
    });
}

@end
