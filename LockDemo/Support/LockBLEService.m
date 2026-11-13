#import "LockBLEService.h"

#import <ThingSmartLockKit/ThingSmartLockKit.h>
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>
#import <ThingSmartDeviceKit/ThingSmartHomeAddMemberRequestModel.h>
#import <YYModel/YYModel.h>

static void LockBLEMain(void (^block)(void)) {
    if (!block) return;
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

static NSString *LockBLEString(id value) {
    if (!value || value == [NSNull null]) return @"";
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [value stringValue];
    return [value description] ?: @"";
}

static NSNumber *LockBLENumber(id value) {
    if (!value || value == [NSNull null]) return nil;
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSString class]]) {
        NSString *string = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (string.length == 0) return nil;
        NSScanner *scanner = [NSScanner scannerWithString:string];
        long long number = 0;
        if ([scanner scanLongLong:&number] && scanner.isAtEnd) return @(number);
    }
    return nil;
}

static BOOL LockBLEBool(id value, BOOL fallback) {
    if ([value isKindOfClass:[NSNumber class]]) return [value boolValue];
    if ([value isKindOfClass:[NSString class]]) {
        NSString *lower = [(NSString *)value lowercaseString];
        if ([lower isEqualToString:@"true"] || [lower isEqualToString:@"1"] || [lower isEqualToString:@"yes"]) return YES;
        if ([lower isEqualToString:@"false"] || [lower isEqualToString:@"0"] || [lower isEqualToString:@"no"]) return NO;
    }
    return fallback;
}

static NSInteger LockBLEMilliseconds(id value) {
    NSNumber *number = LockBLENumber(value);
    if (!number) return 0;
    long long raw = number.longLongValue;
    if (raw > 0 && raw < 100000000000LL) return (NSInteger)(raw * 1000);
    return (NSInteger)raw;
}

static id LockBLEJSONObject(id object) {
    if (!object || object == [NSNull null]) return nil;
    if ([object isKindOfClass:[NSDictionary class]] || [object isKindOfClass:[NSArray class]]) return object;
    if ([object isKindOfClass:[NSString class]]) {
        NSData *data = [(NSString *)object dataUsingEncoding:NSUTF8StringEncoding];
        if (data) {
            id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
            if (json) return json;
        }
        return object;
    }
    if ([object isKindOfClass:[NSNumber class]]) return object;
    if ([object respondsToSelector:@selector(yy_modelToJSONObject)]) {
        id json = [object yy_modelToJSONObject];
        if (json) return json;
    }
    return nil;
}

static void LockBLECollectDictionaries(id object,
                                       NSArray<NSString *> *keys,
                                       NSMutableArray<NSDictionary *> *output,
                                       NSInteger depth) {
    if (!object || object == [NSNull null] || depth > 6) return;
    if ([object isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)object) {
            LockBLECollectDictionaries(item, keys, output, depth + 1);
        }
        return;
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)object;
        BOOL matches = NO;
        for (NSString *key in keys) {
            if (dict[key] && dict[key] != [NSNull null]) {
                matches = YES;
                break;
            }
        }
        if (matches) {
            [output addObject:dict];
            return;
        }
        for (id value in dict.allValues) {
            LockBLECollectDictionaries(value, keys, output, depth + 1);
        }
        return;
    }
    id json = LockBLEJSONObject(object);
    if (json && json != object) {
        LockBLECollectDictionaries(json, keys, output, depth + 1);
    }
}

static id LockBLEFindValue(id object, NSArray<NSString *> *keys, NSInteger depth) {
    if (!object || object == [NSNull null] || depth > 6) return nil;
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)object;
        for (NSString *key in keys) {
            id value = dict[key];
            if (value && value != [NSNull null]) return value;
        }
        for (id value in dict.allValues) {
            id found = LockBLEFindValue(value, keys, depth + 1);
            if (found) return found;
        }
        return nil;
    }
    if ([object isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)object) {
            id found = LockBLEFindValue(item, keys, depth + 1);
            if (found) return found;
        }
        return nil;
    }
    id json = LockBLEJSONObject(object);
    if (json && json != object) {
        return LockBLEFindValue(json, keys, depth + 1);
    }
    return nil;
}

static NSString *LockBLEPasswordTypeName(NSString *authType) {
    NSString *upper = [authType uppercaseString];
    if ([upper containsString:@"OFFLINE"]) return @"离线密码";
    if ([upper containsString:@"ONLINE"] || [upper containsString:@"TEMP"]) return @"在线密码";
    if ([upper isEqualToString:@"0"]) return @"离线密码";
    if ([upper isEqualToString:@"1"]) return @"在线密码";
    return authType.length > 0 ? authType : @"密码";
}

@interface LockBLEService ()

@property (nonatomic, strong) ThingSmartBLELockDevice *bleDevice;
@property (nonatomic, copy) NSString *devId;
@property (nonatomic, assign) long long homeId;
/// 0 未知，1 Pro 门锁，2 标准门锁。
@property (nonatomic, assign) NSInteger proState;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *adminFlags;

@end

@implementation LockBLEService

- (instancetype)initWithDevId:(NSString *)devId homeId:(long long)homeId {
    self = [super init];
    if (self) {
        _devId = [devId copy];
        _homeId = homeId;
        _bleDevice = [[ThingSmartBLELockDevice alloc] initWithDeviceId:devId];
        _adminFlags = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)isProDevice {
    return self.proState == 1;
}

- (BOOL)isBLEConnected {
    return [self.bleDevice isBLEConnected];
}

- (BOOL)isOnline {
    return [self.bleDevice isOnline];
}

#pragma mark - Connection

- (void)autoConnect {
    [self.bleDevice autoConnect];
}

- (void)connectWithTimeout:(NSTimeInterval)timeout
                completion:(void (^)(BOOL connected, NSString *message))completion {
    [self.bleDevice autoConnect];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:MAX(timeout, 1.0)];
    [self pollConnectionUntil:deadline completion:completion];
}

- (void)pollConnectionUntil:(NSDate *)deadline
                 completion:(void (^)(BOOL connected, NSString *message))completion {
    if ([self.bleDevice isBLEConnected]) {
        LockBLEMain(^{
            if (completion) completion(YES, @"蓝牙已连接");
        });
        return;
    }
    if ([[NSDate date] timeIntervalSinceDate:deadline] >= 0) {
        LockBLEMain(^{
            if (completion) completion(NO, @"蓝牙连接超时，请靠近门锁后重试");
        });
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self.bleDevice autoConnect];
        [self pollConnectionUntil:deadline completion:completion];
    });
}

#pragma mark - Unlock / lock

- (void)unlockWithSuccess:(LockVoidBlock)success failure:(LockErrorBlock)failure {
    if ([self.bleDevice isBLEConnected]) {
        [self fetchCurrentMemberWithCompletion:^(NSDictionary *member, NSString *message) {
            NSInteger lockUserId = [member[@"lockUserId"] integerValue];
            if (lockUserId <= 0) {
                [self remoteUnlockWithSuccess:success failure:failure];
                return;
            }
            [self.bleDevice bleUnlock:[NSString stringWithFormat:@"%ld", (long)lockUserId]
                              success:^{
                LockBLEMain(^{
                    if (success) success();
                });
            } failure:^(NSError *error) {
                LockBLEMain(^{
                    if (failure) failure([LockSDKSupport messageForError:error]);
                });
            }];
        }];
        return;
    }
    [self remoteUnlockWithSuccess:success failure:failure];
}

- (void)lockWithSuccess:(LockVoidBlock)success failure:(LockErrorBlock)failure {
    if ([self.bleDevice isBLEConnected]) {
        [self.bleDevice bleManualLock:^{
            LockBLEMain(^{
                if (success) success();
            });
        } failure:^(NSError *error) {
            LockBLEMain(^{
                if (failure) failure([LockSDKSupport messageForError:error]);
            });
        }];
        return;
    }
    if (![self isOnline]) {
        if (failure) failure(@"门锁已离线，无法上锁");
        return;
    }
    [self.bleDevice manualLockWithStatus:^{
        LockBLEMain(^{
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBLEMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)remoteUnlockWithSuccess:(LockVoidBlock)success failure:(LockErrorBlock)failure {
    if (![self isOnline] && ![self isBLEConnected]) {
        if (failure) failure(@"门锁已离线，请靠近门锁连接蓝牙后重试");
        return;
    }
    [self.bleDevice remoteSwitchLock:^(BOOL result) {
        LockBLEMain(^{
            if (!result) {
                if (failure) failure(@"远程开锁失败");
                return;
            }
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBLEMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)remoteLockWithSuccess:(LockVoidBlock)success failure:(LockErrorBlock)failure {
    if (![self isOnline] && ![self isBLEConnected]) {
        if (failure) failure(@"门锁已离线，无法远程上锁");
        return;
    }
    [self.bleDevice manualLockWithStatus:^{
        LockBLEMain(^{
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBLEMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

#pragma mark - Sync / password

- (void)syncDataWithSuccess:(LockVoidBlock)success failure:(LockErrorBlock)failure {
    [self.bleDevice getSyncBatchDataWithDevId:self.devId success:^(id result) {
        [self.bleDevice publishSyncBatchDataSuccess:^{
            LockBLEMain(^{
                if (success) success();
            });
        } failure:^(NSError *error) {
            LockBLEMain(^{
                if (failure) failure([LockSDKSupport messageForError:error]);
            });
        }];
    } failure:^(NSError *error) {
        LockBLEMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)fetchDynamicPasswordWithSuccess:(LockStringBlock)success failure:(LockErrorBlock)failure {
    [self.bleDevice getLockDynamicPasswordWithSuccess:^(NSString *password) {
        LockBLEMain(^{
            if (success) success(LockBLEString(password));
        });
    } failure:^(NSError *error) {
        LockBLEMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

#pragma mark - Pro detection

- (void)detectProWithCompletion:(LockBLEProBlock)completion {
    if (self.proState != 0) {
        BOOL pro = self.proState == 1;
        LockBLEMain(^{
            if (completion) completion(pro);
        });
        return;
    }
    [self.bleDevice getProLockMemberListWithDevId:self.devId success:^(id result) {
        self.proState = 1;
        LockBLEMain(^{
            if (completion) completion(YES);
        });
    } failure:^(NSError *error) {
        self.proState = 2;
        LockBLEMain(^{
            if (completion) completion(NO);
        });
    }];
}

#pragma mark - Members

- (NSDictionary *)normalizeMember:(id)payload {
    NSDictionary *dict = nil;
    id json = LockBLEJSONObject(payload);
    if ([json isKindOfClass:[NSDictionary class]]) {
        dict = json;
    }
    if (!dict) return nil;

    NSString *userId = LockBLEString(LockBLEFindValue(dict, @[@"userId", @"uid"], 0));
    NSString *name = LockBLEString(LockBLEFindValue(dict, @[@"nickName", @"userName", @"name"], 0));
    if (name.length == 0) name = userId.length > 0 ? userId : @"成员";
    NSString *contact = LockBLEString(LockBLEFindValue(dict, @[@"userContact", @"contact"], 0));
    NSNumber *lockUserId = LockBLENumber(LockBLEFindValue(dict, @[@"lockUserId"], 0));
    NSNumber *userType = LockBLENumber(LockBLEFindValue(dict, @[@"userType"], 0));
    id adminValue = LockBLEFindValue(dict, @[@"isAdmin", @"admin"], 0);
    BOOL isAdmin = LockBLEBool(adminValue, userType.integerValue == 1);
    NSString *avatarUrl = LockBLEString(LockBLEFindValue(dict, @[@"avatarUrl", @"avatar"], 0));
    if (userId.length == 0 && !lockUserId) return nil;

    NSDictionary *member = @{
        @"userId": userId,
        @"name": name,
        @"contact": contact,
        @"avatarUrl": avatarUrl,
        @"lockUserId": lockUserId ?: @(0),
        @"userType": userType ?: @(0),
        @"isAdmin": @(isAdmin),
        @"unlockSummary": LockBLEString(LockBLEFindValue(dict, @[@"unlockSummary"], 0))
    };
    if (userId.length > 0) {
        self.adminFlags[userId] = @(isAdmin);
    }
    return member;
}

- (NSArray<NSDictionary *> *)normalizeMembersFromPayload:(id)payload {
    NSMutableArray<NSDictionary *> *dicts = [NSMutableArray array];
    LockBLECollectDictionaries(payload,
                               @[@"userId", @"lockUserId", @"nickName", @"userContact"],
                               dicts,
                               0);
    NSMutableArray<NSDictionary *> *members = [NSMutableArray array];
    for (NSDictionary *dict in dicts) {
        NSDictionary *member = [self normalizeMember:dict];
        if (member) [members addObject:member];
    }
    return members;
}

- (void)fetchCurrentMemberWithCompletion:(LockBLEMemberBlock)completion {
    [self detectProWithCompletion:^(BOOL proDevice) {
        if (proDevice) {
            [self.bleDevice getProCurrentMemberDetailWithDevId:self.devId success:^(NSDictionary *result) {
                [self finishCurrentMemberPayload:result completion:completion];
            } failure:^(NSError *error) {
                [self loadStandardCurrentMemberWithCompletion:completion];
            }];
        } else {
            [self loadStandardCurrentMemberWithCompletion:completion];
        }
    }];
}

- (void)loadStandardCurrentMemberWithCompletion:(LockBLEMemberBlock)completion {
    [self.bleDevice getCurrentMemberDetailWithDevId:self.devId gid:self.homeId success:^(NSDictionary *result) {
        [self finishCurrentMemberPayload:result completion:completion];
    } failure:^(NSError *error) {
        LockBLEMain(^{
            if (completion) completion(nil, [LockSDKSupport messageForError:error]);
        });
    }];
}

- (void)finishCurrentMemberPayload:(id)payload completion:(LockBLEMemberBlock)completion {
    NSMutableArray<NSDictionary *> *dicts = [NSMutableArray array];
    LockBLECollectDictionaries(payload, @[@"userId", @"lockUserId", @"nickName", @"userContact"], dicts, 0);
    NSDictionary *member = nil;
    if (dicts.count > 0) {
        member = [self normalizeMember:dicts.firstObject];
    }
    if (!member) {
        member = [self normalizeMember:payload];
    }
    LockBLEMain(^{
        if (!completion) return;
        if (member) {
            completion(member, nil);
        } else {
            completion(nil, @"未获取到当前成员信息");
        }
    });
}

- (void)fetchMembersWithSuccess:(LockBLEMembersBlock)success failure:(LockErrorBlock)failure {
    [self detectProWithCompletion:^(BOOL proDevice) {
        if (proDevice) {
            [self.bleDevice getProLockMemberListWithDevId:self.devId success:^(id result) {
                NSArray<NSDictionary *> *members = [self normalizeMembersFromPayload:result];
                LockBLEMain(^{
                    if (success) success(members, YES);
                });
            } failure:^(NSError *error) {
                LockBLEMain(^{
                    if (failure) failure([LockSDKSupport messageForError:error]);
                });
            }];
        } else {
            [self.bleDevice getCurrentMemberDetailWithDevId:self.devId gid:self.homeId success:^(NSDictionary *result) {
                [self finishCurrentMemberPayload:result completion:^(NSDictionary *member, NSString *message) {
                    if (!member) {
                        if (failure) failure(message ?: @"未获取到当前成员信息");
                        return;
                    }
                    if (success) success(@[member], NO);
                }];
            } failure:^(NSError *error) {
                LockBLEMain(^{
                    if (failure) failure([LockSDKSupport messageForError:error]);
                });
            }];
        }
    }];
}

- (void)createProMemberWithName:(NSString *)name
                   countryCode:(NSString *)countryCode
                       account:(NSString *)account
                       success:(LockVoidBlock)success
                       failure:(LockErrorBlock)failure {
    if (account.length == 0) {
        if (failure) failure(@"请输入成员账号");
        return;
    }
    ThingSmartHomeAddMemberRequestModel *request = [[ThingSmartHomeAddMemberRequestModel alloc] init];
    request.name = name.length > 0 ? name : account;
    request.account = account;
    request.countryCode = countryCode.length > 0 ? countryCode : @"86";
    request.role = ThingHomeRoleType_Member;
    request.autoAccept = YES;
    [self.bleDevice createProLockMemberWithHomeId:self.homeId
                                     requestModel:request
                                          success:^(NSDictionary *result) {
        LockBLEMain(^{
            if (success) success();
        });
    } failure:^(NSError *error) {
        LockBLEMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

- (BOOL)isAdminForUserId:(NSString *)userId userType:(NSInteger)userType {
    NSNumber *cached = self.adminFlags[userId];
    if (cached) return cached.boolValue;
    return userType == 1;
}

- (void)deleteMemberWithUserId:(NSString *)userId
                       userType:(NSInteger)userType
                        success:(LockVoidBlock)success
                        failure:(LockErrorBlock)failure {
    [self detectProWithCompletion:^(BOOL proDevice) {
        if (!proDevice) {
            LockBLEMain(^{
                if (failure) failure(@"标准门锁仅支持查看当前成员，不能删除成员");
            });
            return;
        }
        BOOL isAdmin = [self isAdminForUserId:userId userType:userType];
        [self.bleDevice removeProLockMemberWithUserId:userId isAdmin:isAdmin success:^{
            LockBLEMain(^{
                if (success) success();
            });
        } failure:^(NSError *error) {
            LockBLEMain(^{
                if (failure) failure([LockSDKSupport messageForError:error]);
            });
        }];
    }];
}

- (void)addPasswordForMemberUserId:(NSString *)userId
                        lockUserId:(NSInteger)lockUserId
                          userType:(NSInteger)userType
                              name:(NSString *)name
                          password:(NSString *)password
                           success:(LockVoidBlock)success
                           failure:(LockErrorBlock)failure {
    (void)lockUserId;
    if (password.length == 0) {
        if (failure) failure(@"请输入开锁密码");
        return;
    }
    if (![self isBLEConnected] && ![self isOnline]) {
        if (failure) failure(@"门锁已离线，请先连接蓝牙或确保网关在线");
        return;
    }
    [self detectProWithCompletion:^(BOOL proDevice) {
        BOOL isAdmin = [self isAdminForUserId:userId userType:userType];
        NSString *unlockName = name.length > 0 ? name : @"密码";
        if (proDevice) {
            [self.bleDevice addProUnlockOpModeForMemberWithMemberId:userId
                                                            isAdmin:isAdmin
                                                       unlockDpCode:@"unlock_password"
                                                       unlockOpType:ThingUnlockOpTypePassword
                                                         unlockName:unlockName
                                                      effectiveDate:nil
                                                        invalidDate:nil
                                                              times:0
                                                         dataLength:(int)password.length
                                                        dataContent:password
                                                            timeout:15
                                                      needHijacking:NO
                                                            appSend:NO
                                                            success:^(id result) {
                LockBLEMain(^{
                    if (success) success();
                });
            } failure:^(NSError *error) {
                LockBLEMain(^{
                    if (failure) failure([LockSDKSupport messageForError:error]);
                });
            }];
        } else {
            [self.bleDevice addUnlockOpmodeForMemberWithMemberId:userId
                                                         isAdmin:isAdmin
                                                    unlockDpCode:@"unlock_password"
                                                    unlockOpType:ThingUnlockOpTypePassword
                                                      unlockName:unlockName
                                                   effectiveDate:nil
                                                     invalidDate:nil
                                                           times:0
                                                      dataLength:(int)password.length
                                                     dataContent:password
                                                         timeout:15
                                                   needHijacking:NO
                                                         success:^(id result) {
                LockBLEMain(^{
                    if (success) success();
                });
            } failure:^(NSError *error) {
                LockBLEMain(^{
                    if (failure) failure([LockSDKSupport messageForError:error]);
                });
            }];
        }
    }];
}

- (void)fetchUnlockSummaryWithUserId:(NSString *)userId
                             success:(LockStringBlock)success
                             failure:(LockErrorBlock)failure {
    [self detectProWithCompletion:^(BOOL proDevice) {
        if (!proDevice) {
            LockBLEMain(^{
                if (success) success(@"");
            });
            return;
        }
        [self.bleDevice getProBoundUnlockOpModeListWithDevId:self.devId userId:userId success:^(id result) {
            NSMutableArray<NSDictionary *> *dicts = [NSMutableArray array];
            LockBLECollectDictionaries(result,
                                       @[@"unlockName", @"opmodeId", @"opmodeValue"],
                                       dicts,
                                       0);
            NSMutableOrderedSet<NSString *> *names = [NSMutableOrderedSet orderedSet];
            for (NSDictionary *dict in dicts) {
                NSString *name = LockBLEString(LockBLEFindValue(dict, @[@"unlockName", @"opmodeValue"], 0));
                if (name.length > 0) [names addObject:name];
            }
            NSString *summary = [[names array] componentsJoinedByString:@"\n"];
            LockBLEMain(^{
                if (success) success(summary);
            });
        } failure:^(NSError *error) {
            LockBLEMain(^{
                if (failure) failure([LockSDKSupport messageForError:error]);
            });
        }];
    }];
}

#pragma mark - Passwords

- (NSDictionary *)normalizePassword:(NSDictionary *)dict fallbackSection:(NSString *)section {
    NSDictionary *raw = dict;
    NSString *name = LockBLEString(LockBLEFindValue(raw, @[@"unlockName", @"pwdName", @"passwordName", @"name"], 0));
    if (name.length == 0) name = @"密码";
    NSNumber *identifier = LockBLENumber(LockBLEFindValue(raw, @[@"unlockBindingId", @"pwdId", @"opmodeId", @"id"], 0));
    NSNumber *sn = LockBLENumber(LockBLEFindValue(raw, @[@"sn", @"pwdSn"], 0));
    NSString *code = LockBLEString(LockBLEFindValue(raw, @[@"password", @"pwd", @"pwdCode", @"code", @"opmodeValue"], 0));
    NSString *authType = LockBLEString(LockBLEFindValue(raw, @[@"authType", @"opModeType", @"opmodeType", @"pwdType"], 0));
    NSString *type = section.length > 0 ? section : LockBLEPasswordTypeName(authType);
    NSInteger effectiveTime = LockBLEMilliseconds(LockBLEFindValue(raw, @[@"effectiveTime", @"gmtStart"], 0));
    NSInteger invalidTime = LockBLEMilliseconds(LockBLEFindValue(raw, @[@"invalidTime", @"gmtExpired"], 0));
    NSInteger phase = [LockBLENumber(LockBLEFindValue(raw, @[@"phase", @"status"], 0)) integerValue];
    return @{
        @"name": name,
        @"code": code,
        @"identifier": identifier ?: @(0),
        @"sn": sn ?: @(0),
        @"type": type,
        @"effectiveTime": @(effectiveTime),
        @"invalidTime": @(invalidTime),
        @"phase": @(phase)
    };
}

- (NSArray<NSDictionary *> *)normalizePasswordsFromPayload:(id)payload fallbackSection:(NSString *)section {
    NSMutableArray<NSDictionary *> *dicts = [NSMutableArray array];
    LockBLECollectDictionaries(payload,
                               @[@"unlockBindingId", @"pwdId", @"unlockName", @"pwdName", @"opmodeValue", @"passwordName"],
                               dicts,
                               0);
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    for (NSDictionary *dict in dicts) {
        [items addObject:[self normalizePassword:dict fallbackSection:section]];
    }
    return items;
}

- (NSString *)passwordTextFromPayload:(id)payload {
    id value = LockBLEFindValue(payload, @[@"pwd", @"password", @"pwdCode", @"code"], 0);
    return LockBLEString(value);
}

- (void)createOfflinePasswordWithName:(NSString *)name
                              success:(LockStringBlock)success
                              failure:(LockErrorBlock)failure {
    NSString *pwdName = name.length > 0 ? name : @"离线密码";
    NSInteger now = (NSInteger)[[NSDate date] timeIntervalSince1970];
    NSInteger expire = now + 7 * 24 * 60 * 60;
    [self detectProWithCompletion:^(BOOL proDevice) {
        void (^handleSuccess)(id) = ^(id result) {
            NSString *password = [self passwordTextFromPayload:result];
            LockBLEMain(^{
                if (success) success(password);
            });
        };
        ThingFailureError handleFailure = ^(NSError *error) {
            LockBLEMain(^{
                if (failure) failure([LockSDKSupport messageForError:error]);
            });
        };
        if (proDevice) {
            [self.bleDevice getProOfflinePasswordWithDevId:self.devId
                                                   pwdType:@"0"
                                                  gmtStart:now
                                                gmtExpired:expire
                                                   pwdName:pwdName
                                                   success:handleSuccess
                                                   failure:handleFailure];
        } else {
            [self.bleDevice getOfflinePasswordWithDevId:self.devId
                                                pwdType:@"0"
                                               gmtStart:now
                                             gmtExpired:expire
                                                pwdName:pwdName
                                                success:handleSuccess
                                                failure:handleFailure];
        }
    }];
}

- (void)createOnlinePasswordWithName:(NSString *)name
                            password:(NSString *)password
                             success:(LockStringBlock)success
                             failure:(LockErrorBlock)failure {
    if (password.length < 4 || password.length > 15) {
        if (failure) failure(@"在线密码长度需为 4-15 位");
        return;
    }
    NSString *pwdName = name.length > 0 ? name : @"在线密码";
    NSInteger now = (NSInteger)[[NSDate date] timeIntervalSince1970];
    NSInteger expire = now + 24 * 60 * 60;
    ThingSmartBLELockScheduleModel *scheduleModel = [[ThingSmartBLELockScheduleModel alloc] init];
    scheduleModel.allDay = YES;
    scheduleModel.effectiveTime = 0;
    scheduleModel.invalidTime = 0;
    scheduleModel.workingDay = 127;
    ThingSmartBLELockScheduleList *schedule = [[ThingSmartBLELockScheduleList alloc] init];
    schedule.scheduleList = [NSMutableArray arrayWithObject:scheduleModel];

    [self detectProWithCompletion:^(BOOL proDevice) {
        ThingSuccessID handleSuccess = ^(id result) {
            NSString *returned = [self passwordTextFromPayload:result];
            NSString *text = returned.length > 0 ? returned : password;
            LockBLEMain(^{
                if (success) success(text);
            });
        };
        ThingFailureError handleFailure = ^(NSError *error) {
            LockBLEMain(^{
                if (failure) failure([LockSDKSupport messageForError:error]);
            });
        };
        if (proDevice) {
            [self.bleDevice getProCustomOnlinePasswordWithDevId:self.devId
                                                          name:pwdName
                                                      password:password
                                                 effectiveTime:now
                                                   invalidTime:expire
                                                      availTime:0
                                                             sn:0
                                                      schedule:schedule
                                                       success:handleSuccess
                                                       failure:handleFailure];
        } else {
            [self.bleDevice getCustomOnlinePasswordWithDevId:self.devId
                                                        name:pwdName
                                               effectiveTime:now
                                                 invalidTime:expire
                                                    password:password
                                                    schedule:schedule
                                                   availTime:0
                                                          sn:0
                                                     success:handleSuccess
                                                     failure:handleFailure];
        }
    }];
}

- (void)fetchPasswordsWithSuccess:(LockArrayBlock)success failure:(LockErrorBlock)failure {
    [self detectProWithCompletion:^(BOOL proDevice) {
        if (proDevice) {
            [self.bleDevice getProPasswordListWithDevId:self.devId
                                              authTypes:@[@"LOCK_TEMP_PWD", @"LOCK_OFFLINE_TEMP_PWD"]
                                                success:^(id result) {
                NSArray<NSDictionary *> *items = [self normalizePasswordsFromPayload:result fallbackSection:nil];
                if (items.count > 0) {
                    LockBLEMain(^{
                        if (success) success(items);
                    });
                } else {
                    [self fetchLegacyPasswordsWithSuccess:success failure:failure];
                }
            } failure:^(NSError *error) {
                [self fetchLegacyPasswordsWithSuccess:success failure:failure];
            }];
        } else {
            [self fetchLegacyPasswordsWithSuccess:success failure:failure];
        }
    }];
}

- (void)fetchLegacyPasswordsWithSuccess:(LockArrayBlock)success failure:(LockErrorBlock)failure {
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    __block NSInteger pending = 2;
    __block BOOL anySuccess = NO;
    __block NSString *lastError = nil;

    void (^finish)(void) = ^{
        pending -= 1;
        if (pending > 0) return;
        LockBLEMain(^{
            if (anySuccess) {
                if (success) success(items);
            } else if (failure) {
                failure(lastError ?: @"获取密码列表失败");
            }
        });
    };

    [self.bleDevice getOnlinePasswordListWithDevId:self.devId availTime:0 success:^(id result) {
        anySuccess = YES;
        [items addObjectsFromArray:[self normalizePasswordsFromPayload:result fallbackSection:@"在线密码"]];
        finish();
    } failure:^(NSError *error) {
        lastError = [LockSDKSupport messageForError:error];
        finish();
    }];

    [self.bleDevice getOfflinePasswordListWithDevId:self.devId
                                            pwdType:@"0"
                                             status:1
                                             offset:0
                                              limit:50
                                            success:^(id result) {
        anySuccess = YES;
        [items addObjectsFromArray:[self normalizePasswordsFromPayload:result fallbackSection:@"离线密码"]];
        finish();
    } failure:^(NSError *error) {
        lastError = [LockSDKSupport messageForError:error];
        finish();
    }];
}

#pragma mark - Records

- (NSDictionary *)normalizeRecord:(id)payload {
    NSDictionary *dict = nil;
    id json = LockBLEJSONObject(payload);
    if ([json isKindOfClass:[NSDictionary class]]) {
        dict = json;
    }
    if (!dict) return nil;
    NSString *name = LockBLEString(LockBLEFindValue(dict, @[@"userName", @"nickName", @"unlockName", @"name"], 0));
    if (name.length == 0) name = @"门锁记录";
    NSString *userId = LockBLEString(LockBLEFindValue(dict, @[@"userId"], 0));
    NSString *avatarUrl = LockBLEString(LockBLEFindValue(dict, @[@"avatarUrl", @"avatar"], 0));
    NSInteger time = LockBLEMilliseconds(LockBLEFindValue(dict, @[@"time", @"unlockTime", @"createTime"], 0));
    NSInteger status = [LockBLENumber(LockBLEFindValue(dict, @[@"status", @"lockStatus"], 0)) integerValue];
    return @{
        @"userName": name,
        @"userId": userId,
        @"avatarUrl": avatarUrl,
        @"time": @(time),
        @"status": @(status),
        @"tags": @(0),
        @"uuid": LockBLEString(LockBLEFindValue(dict, @[@"uuid", @"recordId", @"id"], 0))
    };
}

- (void)fetchUnlockRecordsWithOffset:(NSInteger)offset
                               limit:(NSInteger)limit
                             success:(LockArrayBlock)success
                             failure:(LockErrorBlock)failure {
    [self.bleDevice getUnlockRecordListWithOffset:(int)offset limit:(int)limit success:^(NSArray<ThingSmartBLELockRecordModel *> *records) {
        NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
        for (id record in records) {
            NSDictionary *item = [self normalizeRecord:record];
            if (item) [items addObject:item];
        }
        LockBLEMain(^{
            if (success) success(items);
        });
    } failure:^(NSError *error) {
        LockBLEMain(^{
            if (failure) failure([LockSDKSupport messageForError:error]);
        });
    }];
}

@end
