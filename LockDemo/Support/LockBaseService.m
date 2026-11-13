#import "LockBaseService.h"

#import <ThingSmartLockKit/ThingSmartLockKit.h>
#import <ThingSmartLockKit/ThingSmartLockApi.h>
#import <ThingSmartDeviceCoreKit/ThingSmartSchemaModel.h>

static void LockBaseMain(void (^block)(void)) {
    if (!block) return;
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

static NSString *LockBaseString(id value) {
    if (!value || value == [NSNull null]) return @"";
    return [value isKindOfClass:[NSString class]] ? value : [value description];
}

static NSNumber *LockBaseNumber(id value) {
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
        return @([value longLongValue]);
    }
    return nil;
}

static id LockBaseFirstValue(NSDictionary *dict, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id value = dict[key];
        if (value && value != [NSNull null]) return value;
    }
    return nil;
}

static NSString *LockVideoScheduleJSON(void) {
    return @"[{\"allDay\":true,\"effectiveTime\":0,\"invalidTime\":0,\"workingDay\":127}]";
}

/// 服务端可能返回秒或毫秒，统一转换为秒。
static NSNumber *LockBaseTimeSeconds(id value) {
    if (!value || value == [NSNull null]) return nil;
    NSNumber *number = LockBaseNumber(value);
    if (!number) return nil;
    long long raw = number.longLongValue;
    if (raw > 100000000000LL) return @(raw / 1000);
    return @(raw);
}

static NSNumber *LockBaseFindNumber(id payload, NSArray<NSString *> *keys, NSInteger depth) {
    if (!payload || payload == [NSNull null] || depth > 5) return nil;
    if ([payload isKindOfClass:[NSNumber class]]) return payload;
    if ([payload isKindOfClass:[NSString class]]) {
        NSString *text = payload;
        if (text.length == 0) return nil;
        NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
        if ([text rangeOfCharacterFromSet:nonDigits].location == NSNotFound) {
            return @(text.longLongValue);
        }
        return nil;
    }
    if ([payload isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = payload;
        for (NSString *key in keys) {
            for (NSString *actualKey in dict.allKeys) {
                if (![actualKey isKindOfClass:[NSString class]]) continue;
                if ([actualKey caseInsensitiveCompare:key] != NSOrderedSame) continue;
                NSNumber *number = LockBaseNumber(dict[actualKey]);
                if (number) return number;
            }
        }
        for (id value in dict.allValues) {
            NSNumber *number = LockBaseFindNumber(value, keys, depth + 1);
            if (number) return number;
        }
        return nil;
    }
    if ([payload isKindOfClass:[NSArray class]]) {
        for (id value in (NSArray *)payload) {
            NSNumber *number = LockBaseFindNumber(value, keys, depth + 1);
            if (number) return number;
        }
    }
    return nil;
}

static NSString *LockBaseFindString(id payload, NSArray<NSString *> *keys, NSInteger depth) {
    if (!payload || payload == [NSNull null] || depth > 5) return nil;
    if ([payload isKindOfClass:[NSString class]]) {
        return [(NSString *)payload length] > 0 ? payload : nil;
    }
    if ([payload isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)payload stringValue];
    }
    if ([payload isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = payload;
        for (NSString *key in keys) {
            for (NSString *actualKey in dict.allKeys) {
                if (![actualKey isKindOfClass:[NSString class]]) continue;
                if ([actualKey caseInsensitiveCompare:key] != NSOrderedSame) continue;
                NSString *text = LockBaseString(dict[actualKey]);
                if (text.length > 0) return text;
            }
        }
        for (id value in dict.allValues) {
            NSString *text = LockBaseFindString(value, keys, depth + 1);
            if (text.length > 0) return text;
        }
        return nil;
    }
    if ([payload isKindOfClass:[NSArray class]]) {
        for (id value in (NSArray *)payload) {
            NSString *text = LockBaseFindString(value, keys, depth + 1);
            if (text.length > 0) return text;
        }
    }
    return nil;
}

static NSString *LockUnlockTypeName(ThingLockUnlockType type) {
    switch (type) {
        case ThingLockUnlockTypeFingerprint: return @"指纹";
        case ThingLockUnlockTypePassword: return @"密码";
        case ThingLockUnlockTypeTemporary: return @"临时密码";
        case ThingLockUnlockTypeDynamic: return @"动态密码";
        case ThingLockUnlockTypeCard: return @"卡片";
        case ThingLockUnlockTypeFace: return @"人脸";
        case ThingLockUnlockTypeKey: return @"钥匙";
        case ThingLockUnlockTypeFingerVein: return @"指静脉";
        case ThingLockUnlockTypeHand: return @"掌纹";
        case ThingLockUnlockTypeEye: return @"虹膜";
        case ThingLockUnlockTypeRemote: return @"远程开锁";
        default: return @"开锁方式";
    }
}

@interface LockBaseService () <ThingSmartLockDeviceDelegate>
@property (nonatomic, strong) ThingSmartLockDevice *lockDevice;
@property (nonatomic, strong) ThingSmartLockApi *lockApi;
@property (nonatomic, copy) NSString *devId;
@end

@implementation LockBaseService

- (instancetype)initWithDevId:(NSString *)devId {
    self = [super init];
    if (self) {
        _devId = [devId copy];
        _lockDevice = [[ThingSmartLockDevice alloc] initWithDeviceId:devId];
        _lockDevice.delegate = self;
        _lockApi = [[ThingSmartLockApi alloc] init];
    }
    return self;
}

- (BOOL)isOnline {
    return self.lockDevice.deviceModel.isOnline;
}

#pragma mark - Device delegate

- (void)deviceOnlineUpdate:(ThingSmartDevice *)device {
    if (self.onOnlineChanged) self.onOnlineChanged(device.deviceModel.isOnline);
}

- (void)deviceInfoUpdate:(ThingSmartDevice *)device {
    if (self.onOnlineChanged) self.onOnlineChanged(device.deviceModel.isOnline);
}

- (void)device:(ThingSmartLockDevice *)device didReceiveRemoteUnlockRequest:(NSInteger)seconds {
    LockBaseMain(^{
        if (self.onRemoteUnlockRequest) self.onRemoteUnlockRequest(seconds);
    });
}

#pragma mark - Password

- (void)fetchDynamicPasswordWithSuccess:(LockStringBlock)success failure:(LockErrorBlock)failure {
    [self.lockDevice getLockDynamicPasswordWithSuccess:^(NSString *password) {
        LockBaseMain(^{
            if (success) success(LockBaseString(password));
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)createTempPasswordWithName:(NSString *)name
                          password:(NSString *)password
                     effectiveDate:(NSDate *)effectiveDate
                       invalidDate:(NSDate *)invalidDate
                           success:(LockVoidBlock)success
                           failure:(LockErrorBlock)failure {
    [self.lockDevice createLockTempPwd:password
                                  name:name
                         effectiveDate:effectiveDate
                           invalidDate:invalidDate
                               success:^(BOOL result) {
        LockBaseMain(^{
            if (!result) {
                if (failure) failure(@"创建临时密码失败");
                return;
            }
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)fetchTempPasswordsWithSuccess:(LockArrayBlock)success failure:(LockErrorBlock)failure {
    [self.lockDevice getLockTempPwdListWithSuccess:^(NSArray<ThingSmartLockTempPwdModel *> *models) {
        NSMutableArray *items = [NSMutableArray array];
        for (ThingSmartLockTempPwdModel *model in models) {
            [items addObject:@{
                @"name": LockBaseString(model.name),
                @"code": @(model.code),
                @"sn": @(model.sn),
                @"phone": LockBaseString(model.phone),
                @"effectiveTime": @(model.effectiveTime),
                @"invalidTime": @(model.invalidTime),
                @"phase": @(model.phase),
                @"effective": @(model.effective)
            }];
        }
        LockBaseMain(^{
            if (success) success(items);
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)deleteTempPasswordWithCode:(NSInteger)code
                           success:(LockVoidBlock)success
                           failure:(LockErrorBlock)failure {
    [self.lockDevice deleteLockTempPwdWithPwdId:code force:YES success:^(BOOL result) {
        LockBaseMain(^{
            if (!result) {
                if (failure) failure(@"删除临时密码失败");
                return;
            }
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

#pragma mark - Video / photo temporary passwords

- (NSInteger)tempPasswordDpId {
    NSArray<NSString *> *codes = @[@"unlock_temporary", @"temporary_password_creat"];
    NSArray<ThingSmartSchemaModel *> *schemas = self.lockDevice.deviceModel.schemaArray;
    for (NSString *code in codes) {
        for (ThingSmartSchemaModel *schema in schemas) {
            if (![schema.code isEqualToString:code]) continue;
            NSInteger dpId = schema.dpId.integerValue;
            if (dpId > 0) return dpId;
        }
    }
    return 69;
}

- (BOOL)isTempPasswordEntry:(NSDictionary *)dict video:(BOOL)video {
    if (video) {
        if (LockBaseFirstValue(dict, @[@"unlockBindingId", @"unlockId"]) != nil) return YES;
        if (LockBaseFirstValue(dict, @[@"id", @"pwdId"]) != nil &&
            LockBaseFirstValue(dict, @[@"name", @"pwdName", @"phase", @"sn"]) != nil) {
            return YES;
        }
        return NO;
    }
    if (LockBaseFirstValue(dict, @[@"pwdId", @"id"]) == nil) return NO;
    return LockBaseFirstValue(dict, @[@"sn", @"name", @"pwdName", @"phase"]) != nil;
}

- (void)collectTempPasswordDictionaries:(id)payload
                                   into:(NSMutableArray<NSDictionary *> *)result
                                  video:(BOOL)video
                                  depth:(NSInteger)depth {
    if (!payload || payload == [NSNull null] || depth > 5) return;
    if ([payload isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)payload) {
            [self collectTempPasswordDictionaries:item into:result video:video depth:depth + 1];
        }
        return;
    }
    if (![payload isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *dict = payload;
    if ([self isTempPasswordEntry:dict video:video]) {
        [result addObject:dict];
        return;
    }
    for (id value in dict.allValues) {
        [self collectTempPasswordDictionaries:value into:result video:video depth:depth + 1];
    }
}

- (NSDictionary *)normalizeTempPassword:(NSDictionary *)dict video:(BOOL)video {
    NSArray<NSString *> *codeKeys = video
        ? @[@"unlockBindingId", @"unlockId", @"pwdId", @"id"]
        : @[@"pwdId", @"id"];
    NSNumber *code = LockBaseNumber(LockBaseFirstValue(dict, codeKeys)) ?: @(0);
    NSNumber *sn = LockBaseNumber(LockBaseFirstValue(dict, @[@"sn", @"pwdSn", @"passwordSn"])) ?: @(0);
    NSString *name = LockBaseString(LockBaseFirstValue(dict, @[@"name", @"pwdName", @"unlockName", @"nickName"]));
    if (name.length == 0) name = @"临时密码";
    NSNumber *start = LockBaseTimeSeconds(LockBaseFirstValue(
            dict, @[@"effectiveTime", @"gmtStart", @"startTime", @"beginTime"]));
    NSNumber *end = LockBaseTimeSeconds(LockBaseFirstValue(
            dict, @[@"invalidTime", @"gmtExpired", @"endTime", @"expireTime"]));
    NSNumber *phase = LockBaseNumber(LockBaseFirstValue(dict, @[@"phase", @"status"])) ?: @(0);

    BOOL effective = YES;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (start.longLongValue > 0 && now < start.longLongValue) effective = NO;
    if (end.longLongValue > 0 && now > end.longLongValue) effective = NO;

    NSMutableDictionary *item = [@{
        @"name": name,
        @"code": code,
        @"sn": sn,
        @"effectiveTime": start ?: @(0),
        @"invalidTime": end ?: @(0),
        @"phase": phase,
        @"effective": @(effective)
    } mutableCopy];
    NSString *password = LockBaseString(LockBaseFirstValue(dict, @[@"pwd", @"password", @"pwdCode"]));
    if (password.length > 0) item[@"password"] = password;
    return item;
}

- (void)deliverTempPasswordsFromResult:(id)result
                                 video:(BOOL)video
                               success:(LockArrayBlock)success {
    NSMutableArray<NSDictionary *> *dicts = [NSMutableArray array];
    [self collectTempPasswordDictionaries:result into:dicts video:video depth:0];
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *dict in dicts) {
        [items addObject:[self normalizeTempPassword:dict video:video]];
    }
    LockBaseMain(^{
        if (success) success(items);
    });
}

- (void)fetchVideoTempPasswordSnWithSuccess:(LockDictionaryBlock)success
                                    failure:(LockErrorBlock)failure {
    NSInteger dpId = [self tempPasswordDpId];
    [self.lockApi getVideoLockSnNumberWithDevId:self.devId
                                           dpId:dpId
                                        success:^(id result) {
        NSNumber *sn = LockBaseFindNumber(result, @[@"sn", @"deviceSn", @"hardwareSn", @"snNumber"], 0);
        LockBaseMain(^{
            if (success) success(@{@"dpId": @(dpId), @"sn": sn ?: @(0)});
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)fetchPhotoTempPasswordsWithSuccess:(LockArrayBlock)success
                                   failure:(LockErrorBlock)failure {
    [self.lockApi getPhotoLockTemporaryPasswordWithDevId:self.devId success:^(id result) {
        [self deliverTempPasswordsFromResult:result video:NO success:success];
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)fetchVideoTempPasswordsWithSuccess:(LockArrayBlock)success
                                   failure:(LockErrorBlock)failure {
    [self.lockApi getVideoLockTemporaryPasswordWithDevId:self.devId
                                               authTypes:@[]
                                                 success:^(id result) {
        [self deliverTempPasswordsFromResult:result video:YES success:success];
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)createPhotoTempPasswordWithName:(NSString *)name
                               password:(NSString *)password
                          effectiveDate:(NSDate *)effectiveDate
                            invalidDate:(NSDate *)invalidDate
                                success:(LockVoidBlock)success
                                failure:(LockErrorBlock)failure {
    NSInteger start = (NSInteger)([effectiveDate timeIntervalSince1970] * 1000);
    NSInteger end = (NSInteger)([invalidDate timeIntervalSince1970] * 1000);
    [self.lockApi addPhotoLockTemporaryPasswordWithDevId:self.devId
                                                    name:name
                                                   phone:@""
                                           effectiveTime:start
                                             invalidTime:end
                                                password:password
                                                schedule:LockVideoScheduleJSON()
                                             countryCode:@""
                                               availTime:0
                                                 success:^(id result) {
        LockBaseMain(^{
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)createVideoTempPasswordWithName:(NSString *)name
                               password:(NSString *)password
                                     sn:(NSInteger)sn
                          effectiveDate:(NSDate *)effectiveDate
                            invalidDate:(NSDate *)invalidDate
                                success:(LockVoidBlock)success
                                failure:(LockErrorBlock)failure {
    NSInteger start = (NSInteger)[effectiveDate timeIntervalSince1970];
    NSInteger end = (NSInteger)[invalidDate timeIntervalSince1970];
    [self.lockApi addVideoLockTemporaryPasswordWithDevId:self.devId
                                                    name:name
                                                password:password
                                           effectiveTime:start
                                             invalidTime:end
                                               availTime:0
                                                      sn:sn
                                                schedule:LockVideoScheduleJSON()
                                                symbolic:NO
                                                dpTunnel:2
                                                 success:^(id result) {
        LockBaseMain(^{
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)createVideoOfflinePasswordWithName:(NSString *)name
                             effectiveDate:(NSDate *)effectiveDate
                               invalidDate:(NSDate *)invalidDate
                                   success:(LockStringBlock)success
                                   failure:(LockErrorBlock)failure {
    NSInteger start = (NSInteger)[effectiveDate timeIntervalSince1970];
    NSInteger end = (NSInteger)[invalidDate timeIntervalSince1970];
    [self.lockApi addVideoLockOfflinePasswordWithDevId:self.devId
                                               pwdType:@"0"
                                              gmtStart:start
                                            gmtExpired:end
                                               pwdName:name
                                           countryCode:@""
                                                mobile:@""
                                               success:^(id result) {
        NSString *password = LockBaseFindString(result, @[@"pwd", @"password", @"pwdCode"], 0) ?: @"";
        LockBaseMain(^{
            if (success) success(password);
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)deletePhotoTempPasswordWithId:(NSInteger)pwdId
                              success:(LockVoidBlock)success
                              failure:(LockErrorBlock)failure {
    [self.lockApi deletePhotoLockTemporaryPasswordWithDevId:self.devId
                                                      pwdId:pwdId
                                                    success:^(id result) {
        LockBaseMain(^{
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)deleteVideoTempPasswordWithId:(NSInteger)unlockBindingId
                              success:(LockVoidBlock)success
                              failure:(LockErrorBlock)failure {
    [self.lockApi deleteVideoLockTemporaryPasswordWithDevId:self.devId
                                           unlockBindingId:unlockBindingId
                                                  symbolic:NO
                                                  dpTunnel:2
                                                   success:^(id result) {
        LockBaseMain(^{
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

#pragma mark - Records

- (void)fetchUnlockRecordsWithOffset:(NSInteger)offset
                               limit:(NSInteger)limit
                             success:(LockArrayBlock)success
                             failure:(LockErrorBlock)failure {
    [self.lockDevice getUnlockRecordList:offset limit:limit success:^(NSArray<ThingSmartLockRecordModel *> *records) {
        NSMutableArray *items = [NSMutableArray array];
        for (ThingSmartLockRecordModel *record in records) {
            [items addObject:@{
                @"userName": LockBaseString(record.userName),
                @"userId": LockBaseString(record.userId),
                @"avatarUrl": LockBaseString(record.avatarUrl),
                @"time": @(record.time),
                @"status": @(record.status),
                @"tags": @(record.tags),
                @"uuid": LockBaseString(record.uuid)
            }];
        }
        LockBaseMain(^{
            if (success) success(items);
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

#pragma mark - Remote unlock

- (void)replyRemoteUnlock:(BOOL)open
                  success:(LockVoidBlock)success
                  failure:(LockErrorBlock)failure {
    [self.lockDevice replyRemoteUnlock:open success:^{
        LockBaseMain(^{
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

#pragma mark - Members

- (NSDictionary *)normalizeMember:(ThingSmartLockMemberModel *)member {
    NSMutableString *summary = [NSMutableString string];
    for (ThingSmartLockRelationModel *relation in member.unlockRelations) {
        if (summary.length > 0) [summary appendString:@"\n"];
        [summary appendFormat:@"%@  SN=%ld", LockUnlockTypeName(relation.unlockType), (long)relation.sn];
    }
    NSDictionary *origin = [member.originJson isKindOfClass:[NSDictionary class]] ? member.originJson : @{};
    NSNumber *lockUserId = [origin[@"lockUserId"] isKindOfClass:[NSNumber class]] ? origin[@"lockUserId"] : @(0);
    NSNumber *originUserType = [origin[@"userType"] isKindOfClass:[NSNumber class]] ? origin[@"userType"] : @(member.userType);
    return @{
        @"userId": LockBaseString(member.userId),
        @"name": LockBaseString(member.userName),
        @"contact": LockBaseString(member.contact),
        @"userType": @(member.userType),
        @"lockUserId": lockUserId,
        @"originUserType": originUserType,
        @"unlockSummary": summary,
        @"unlockCount": @(member.unlockRelations.count)
    };
}

- (void)fetchMembersWithSuccess:(LockArrayBlock)success failure:(LockErrorBlock)failure {
    [self.lockDevice getLockMemberListWithSuccess:^(NSArray<ThingSmartLockMemberModel *> *members) {
        NSMutableArray *items = [NSMutableArray array];
        for (ThingSmartLockMemberModel *member in members) {
            [items addObject:[self normalizeMember:member]];
        }
        LockBaseMain(^{
            if (success) success(items);
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)createMemberWithName:(NSString *)name
                     success:(LockVoidBlock)success
                     failure:(LockErrorBlock)failure {
    [self.lockDevice addLockNormalUserWithUserName:name
                                       avatarImage:nil
                                   unlockRelations:@[]
                                           success:^(NSString *userId) {
        LockBaseMain(^{
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)deleteMemberWithUserId:(NSString *)userId
                       success:(LockVoidBlock)success
                       failure:(LockErrorBlock)failure {
    [self.lockDevice deleteLockUserWithUserId:userId success:^(BOOL result) {
        LockBaseMain(^{
            if (!result) {
                if (failure) failure(@"删除成员失败");
                return;
            }
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)addUnlockRelationWithMemberUserId:(NSString *)userId
                                       sn:(NSInteger)sn
                                  success:(LockVoidBlock)success
                                  failure:(LockErrorBlock)failure {
    if (sn <= 0) {
        if (failure) failure(@"请输入有效的密码编号（SN）");
        return;
    }
    [self.lockDevice getLockMemberListWithSuccess:^(NSArray<ThingSmartLockMemberModel *> *members) {
        ThingSmartLockMemberModel *target = nil;
        for (ThingSmartLockMemberModel *member in members) {
            if ([member.userId isEqualToString:userId]) {
                target = member;
                break;
            }
        }
        if (!target) {
            LockBaseMain(^{
                if (failure) failure(@"成员不存在，请刷新后重试");
            });
            return;
        }
        NSMutableArray<ThingSmartLockRelationModel *> *relations = [NSMutableArray array];
        for (ThingSmartLockRelationModel *relation in target.unlockRelations) {
            if (relation.unlockType == ThingLockUnlockTypePassword && relation.sn == sn) {
                LockBaseMain(^{
                    if (failure) failure(@"该密码编号已绑定到当前成员");
                });
                return;
            }
            ThingSmartLockRelationModel *copy = [[ThingSmartLockRelationModel alloc] init];
            copy.unlockType = relation.unlockType;
            copy.sn = relation.sn;
            [relations addObject:copy];
        }
        ThingSmartLockRelationModel *newRelation = [[ThingSmartLockRelationModel alloc] init];
        newRelation.unlockType = ThingLockUnlockTypePassword;
        newRelation.sn = sn;
        [relations addObject:newRelation];

        [self.lockDevice updateLockNormalUserWithUserId:target.userId
                                               userName:nil
                                            avatarImage:nil
                                        unlockRelations:relations
                                                success:^(BOOL result) {
            LockBaseMain(^{
                if (!result) {
                    if (failure) failure(@"绑定开锁方式失败");
                    return;
                }
                if (success) success();
            });
        } failure:^(NSError *error) {
            LockBaseMain(^{
                if (failure) failure([LockSDKSupport messageForError:error]);
            });
        }];
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)fetchUnlockSummaryWithUserId:(NSString *)userId
                             success:(LockStringBlock)success
                             failure:(LockErrorBlock)failure {
    [self.lockDevice getLockMemberListWithSuccess:^(NSArray<ThingSmartLockMemberModel *> *members) {
        ThingSmartLockMemberModel *target = nil;
        for (ThingSmartLockMemberModel *member in members) {
            if ([member.userId isEqualToString:userId]) {
                target = member;
                break;
            }
        }
        NSMutableString *summary = [NSMutableString string];
        for (ThingSmartLockRelationModel *relation in target.unlockRelations) {
            if (summary.length > 0) [summary appendString:@"\n"];
            [summary appendFormat:@"%@  SN=%ld", LockUnlockTypeName(relation.unlockType), (long)relation.sn];
        }
        LockBaseMain(^{
            if (success) success(summary);
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

#pragma mark - Panel members (video / photo)

- (void)collectPanelDictionaries:(id)payload
                            into:(NSMutableArray<NSDictionary *> *)result
                           depth:(NSInteger)depth {
    if (!payload || payload == [NSNull null] || depth > 4) return;
    if ([payload isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)payload) {
            [self collectPanelDictionaries:item into:result depth:depth + 1];
        }
        return;
    }
    if (![payload isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *dict = payload;
    NSString *userId = LockBaseString(LockBaseFirstValue(dict, @[@"userId", @"uid"]));
    if (userId.length > 0) {
        [result addObject:dict];
        return;
    }
    for (id value in dict.allValues) {
        [self collectPanelDictionaries:value into:result depth:depth + 1];
    }
}

- (NSDictionary *)normalizePanelMember:(NSDictionary *)dict {
    NSString *userId = LockBaseString(LockBaseFirstValue(dict, @[@"userId", @"uid"]));
    if (userId.length == 0) return nil;
    NSString *name = LockBaseString(LockBaseFirstValue(dict, @[@"userName", @"nickName", @"name"]));
    if (name.length == 0) name = userId;
    NSNumber *lockUserId = LockBaseNumber(LockBaseFirstValue(dict, @[@"lockUserId"]));
    NSNumber *userType = LockBaseNumber(LockBaseFirstValue(dict, @[@"userType"])) ?: @(0);
    NSNumber *admin = LockBaseNumber(LockBaseFirstValue(dict, @[@"isAdmin", @"admin"]));
    NSString *summary = LockBaseString(LockBaseFirstValue(dict, @[@"unlockSummary"]));
    return @{
        @"userId": userId,
        @"name": name,
        @"contact": LockBaseString(LockBaseFirstValue(dict, @[@"userContact", @"contact"])),
        @"userType": userType,
        @"lockUserId": lockUserId ?: @(0),
        @"originUserType": userType,
        @"isAdmin": @(admin ? admin.boolValue : userType.integerValue == 1),
        @"unlockSummary": summary,
        @"unlockCount": @(summary.length > 0 ? 1 : 0)
    };
}

- (void)fetchPanelMembersWithSuccess:(LockArrayBlock)success failure:(LockErrorBlock)failure {
    __weak typeof(self) weakSelf = self;
    [self.lockApi getPhotoLockMemberPanelListWithDevId:self.devId success:^(id result) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSMutableArray<NSDictionary *> *dicts = [NSMutableArray array];
        [self collectPanelDictionaries:result into:dicts depth:0];
        NSMutableArray *items = [NSMutableArray array];
        for (NSDictionary *dict in dicts) {
            NSDictionary *item = [self normalizePanelMember:dict];
            if (item) [items addObject:item];
        }
        if (items.count == 0) {
            [self fetchMembersWithSuccess:success failure:failure];
            return;
        }
        LockBaseMain(^{
            if (success) success(items);
        });
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self fetchMembersWithSuccess:success failure:failure];
    }];
}

- (void)collectUnlockEntries:(id)payload
                        into:(NSMutableArray<NSString *> *)entries
                       depth:(NSInteger)depth {
    if (!payload || payload == [NSNull null] || depth > 5) return;
    if ([payload isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)payload) {
            [self collectUnlockEntries:item into:entries depth:depth + 1];
        }
        return;
    }
    if (![payload isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *dict = payload;
    NSNumber *unlockId = LockBaseNumber(LockBaseFirstValue(
            dict, @[@"unlockId", @"opmodeId", @"unlockBindingId"]));
    NSString *name = LockBaseString(LockBaseFirstValue(
            dict, @[@"unlockName", @"opmodeValue"]));
    if (unlockId || name.length > 0) {
        NSString *line = name.length > 0 ? name : @"开锁方式";
        if (unlockId) line = [line stringByAppendingFormat:@"  id=%@", unlockId];
        if (![entries containsObject:line]) [entries addObject:line];
        return;
    }
    for (id value in dict.allValues) {
        [self collectUnlockEntries:value into:entries depth:depth + 1];
    }
}

- (void)fetchPanelUnlockSummaryWithUserId:(NSString *)userId
                                  success:(LockStringBlock)success
                                  failure:(LockErrorBlock)failure {
    __weak typeof(self) weakSelf = self;
    [self.lockApi getPhotoLockPanelMemberDetailWithDevId:self.devId userId:userId success:^(id result) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSMutableArray<NSString *> *entries = [NSMutableArray array];
        [self collectUnlockEntries:result into:entries depth:0];
        if (entries.count == 0) {
            [self fetchUnlockSummaryWithUserId:userId success:success failure:failure];
            return;
        }
        LockBaseMain(^{
            if (success) success([entries componentsJoinedByString:@"\n"]);
        });
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self fetchUnlockSummaryWithUserId:userId success:success failure:failure];
    }];
}

- (void)createPanelMemberWithName:(NSString *)name
                          success:(LockVoidBlock)success
                          failure:(LockErrorBlock)failure {
    NSInteger birthday = (NSInteger)([[NSDate date] timeIntervalSince1970] * 1000);
    [self.lockApi addPhotoLockPanelMemberWithDevId:self.devId
                                              name:name
                                            avatar:@""
                                               sex:@"0"
                                          birthday:birthday
                                            height:180
                                            weight:80
                                   localHeightUnit:@"CM"
                                           success:^(id result) {
        LockBaseMain(^{
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)deletePanelMemberWithUserId:(NSString *)userId
                            success:(LockVoidBlock)success
                            failure:(LockErrorBlock)failure {
    [self.lockApi deletePhotoLockPanelMemberWithDevId:self.devId userId:userId success:^(id result) {
        LockBaseMain(^{
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBaseMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

@end
