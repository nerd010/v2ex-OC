//
//  WTAccountTool.m
//  v2ex
//
//  Created by 无头骑士 GJ on 16/2/20.
//  Copyright © 2016年 无头骑士 GJ. All rights reserved.
//

#import "WTAccountTool.h"
#import "WTHttpTool.h"
#import "MJExtension.h"
#import "WTURLConst.h"
#import "HTMLParser.h"
#import "HTMLNode.h"
#import "WTHttpTool.h"
#import "WTAccount.h"
#import "WTUser.h"
#import "WTExtension.h"
#import "NSString+Regex.h"
#import "NSString+YYAdd.h"
@implementation WTAccountTool

/**
 *  登陆
 *
 *  @param param   请求参数
 *  @param success 请求成功的回调
 *  @param failure 请求失败的回调
 */
+ (void)loginWithParam:(WTAccountParam *)param success:(void(^)())success failure:(void(^)(NSError *error))failure
{
    // 1、切换帐号有缓存问题
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
    
    
    // 2、请求参数
    __block WTAccountParam *blockParam = param;

    // 3、请求地址
    NSString *urlString = [WTHTTPBaseUrl stringByAppendingPathComponent: WTLoginUrl];

    // 4、登陆到登陆页面，并设置请求参数
    [WTHttpTool GET: urlString parameters: nil success:^(id responseObject) {

        blockParam = [WTAccountTool parseLoginHtmlWithData: responseObject param: blockParam];
        
        // 5、提交登陆请求
        [WTHttpTool POST: urlString parameters: blockParam.mj_keyValues success:^(id responseObject) {
            
            NSString *html = [[NSString alloc] initWithData: responseObject encoding: NSUTF8StringEncoding];
            WTLog(@"loginHTML:%@", html);
            
            
            NSError *loginError = nil;
            if ([html containsString: @"notifications"])    // 登陆成功
            {
                WTLog(@"登陆成功")
                [WTAccount shareAccount].usernameOrEmail = blockParam.u;
                [WTAccount shareAccount].password = blockParam.p;
                [[WTAccount shareAccount] saveAccount];
                
                // 是否已经领取过奖励
                if ([html containsString: @"领取今日的登录奖励"])
                {
                    [WTAccount shareAccount].receiveAwards = NO;
                    [self getOnceWithLoginSuccess];
                }
                else
                {
                    [WTAccount shareAccount].receiveAwards = YES;
                }
                
                
                if (success)
                {
                    success();
                }
                return;
            }
            else if ([html containsString: @"用户名和密码无法匹配"])
            {
                WTLog(@"用户名和密码无法匹配");
                loginError = [NSError errorWithDomain: WTHTTPBaseUrl code: 400 userInfo: @{@"message" : @"用户名和密码无法匹配"}];
            }
            else
            {
                WTLog(@"未知错误")
                [[WTAccount shareAccount] removeAccount];
                loginError = [NSError errorWithDomain: WTHTTPBaseUrl code: 1001 userInfo: @{@"message" : @"服务器异常，请稍候重试"}];
            }
            
            if (failure)
            {
                failure(loginError);
            }
        } failure:^(NSError *error) {
            WTLog(@"error1:%@",error);
        }];
        
    } failure:^(NSError *error) {
        WTLog(@"error2:%@",error);
    }];
}

/**
 *  根据网址获取用户信息
 *
 *  @param urlString 网址
 *  @param success   请求成功的回调
 *  @param failure   请求失败的回调
 */
+ (void)getUserInfoWithUrlString:(NSString *)urlString success:(void(^)(WTUser *user))success failure:(void(^)(NSError *error))failure
{
//    NSString *url = @"http://www.v2ex.com/member/misaka14";
    
//    [WTHttpTool GET: url parameters: nil success:^(id responseObject) {
//        
//        NSString *html = [[NSString alloc] initWithData: responseObject encoding: NSUTF8StringEncoding];
//        WTLog(@"html:%@", html);
//        WTUser *user = [self getUserInfoWithData: responseObject];
//        
//    } failure:^(NSError *error) {
//        if (failure)
//        {
//            failure(error);
//        }
//    }];
    
    [WTHttpTool GETHTML: urlString parameters: nil success:^(id responseObject) {
        //NSString *html = [[NSString alloc] initWithData: responseObject encoding: NSUTF8StringEncoding];
        //WTLog(@"html:%@", html);
        WTUser *user = [self getUserInfoWithData: responseObject];
        if (success)
        {
            success(user);
        }
    } failure:^(NSError *error) {
        if (failure)
        {
            failure(error);
        }
    }];
}

/**
 *  根据url获取用户的全部话题
 *
 *  @param urlString url
 *  @param success   请求成功的回调
 *  @param failure   请求失败的回调
 */
+ (void)getMeAllTopicWithUrlString:(NSString *)urlString success:(void(^)(NSMutableArray<WTTopic *> *topics))success failure:(void(^)(NSError *error))failure
{
    [WTHttpTool GET: urlString parameters: nil success:^(id responseObject) {
        //NSString *html = [[NSString alloc] initWithData: responseObject encoding: NSUTF8StringEncoding];
        
        NSMutableArray *topics = [WTExtension getMeAllTopicsWithData: responseObject];
        if (success)
        {
            success(topics);
        }
    } failure:^(NSError *error) {
        if (failure)
        {
            failure(error);
        }
    }];
}


/**
 *  根据urlString查找用户回复别人的话题
 *
 *  @param urlString url
 *  @param success   请求成功的回调
 *  @param failure   请求失败的回调
 */
+ (void)getReplyTopicsWithUrlString:(NSString *)urlString success:(void(^)(NSMutableArray<WTTopic *> *topics))success failure:(void(^)(NSError *error))failure
{
    [WTHttpTool GET: urlString parameters: nil success:^(id responseObject) {
    
        //NSString *html = [[NSString alloc] initWithData: responseObject encoding: NSUTF8StringEncoding];
        NSMutableArray<WTTopic *> *topics = [WTExtension getReplyTopicsWithData: responseObject];
        if (success)
        {
            success(topics);
        }
        
    } failure:^(NSError *error) {
        if (failure)
        {
            failure(error);
        }
    }];
}

/**
 *  根据urlString领取今日奖励
 *
 *  @param urlString url
 *  @param success   请求成功的回调
 *  @param failure   请求失败的回调
 */
+ (void)signWithUrlString:(NSString *)urlString success:(void(^)())success failure:(void(^)(NSError *error))failure
{
    [WTHttpTool GET: urlString parameters: nil success:^(id responseObject) {
        
        NSString *html = [[NSString alloc] initWithData: responseObject encoding: NSUTF8StringEncoding];
        
        WTLog(@"signWithUrlString:%@", html)
        
        if (success)
        {
            success();
        }
    } failure:^(NSError *error) {
        if (failure)
        {
            failure(error);
        }
    }];
}



#pragma mark - Private Method
/**
 *  根据网页二进制解析出需要的登陆参数
 *
 *  @param data  网页二进制
 *  @param param 登陆参数
 *
 *  @return 登陆参数
 */
+ (WTAccountParam *)parseLoginHtmlWithData:(NSData *)data param:(WTAccountParam *)param
{
    HTMLParser *parser = [[HTMLParser alloc] initWithData: data error: nil];
    
    // 1、把 html 当中的body部分取出来
    HTMLNode *bodyNode = [parser body];
    
    // 2、获取 name = 'once' 的value值
    HTMLNode *onceNode = [bodyNode findChildrenWithAttribute: @"name" matchingName: @"once" allowPartial: YES].lastObject;
    NSString *once = [onceNode getAttributeNamed: @"value"];
    
    // 3、获取 name = 'next' 的value值
    HTMLNode *nextNode = [bodyNode findChildrenWithAttribute: @"name" matchingName: @"next" allowPartial: YES].lastObject;
    NSString *next = [nextNode getAttributeNamed: @"value"];
    
    // 4、设置属性
    param.once = once;
    param.next = next;
    
    return  param;
}


/**
 *  根据url获取用户的消息
 *
 *  @param urlString url
 *  @param success   请求成功的回调
 *  @param failure   请求失败的回调
 */
+ (void)getNotificationWithUrlString:(NSString *)urlString success:(void(^)(NSMutableArray<WTNotification *> *notifications))success failure:(void(^)(NSError *error))failure
{
    
    [WTHttpTool GET: urlString parameters: nil success:^(id responseObject) {
        
        //NSString *html = [[NSString alloc] initWithData: responseObject encoding: NSUTF8StringEncoding];
        NSMutableArray *notifications = [self getNotificationsWithData: responseObject];
        if (success)
        {
            success(notifications);
        }
        
    } failure:^(NSError *error) {
        if (failure)
        {
            failure(error);
        }
    }];
}

/**
 *  根据二进制解析出用户信息
 *
 *  @param data 二进制
 *
 *  @return 用户信息模型
 */
+ (WTUser *)getUserInfoWithData:(NSData *)data
{
    HTMLParser *parser = [[HTMLParser alloc] initWithData: data error: nil];
    
    // 1、把 html 当中的body部分取出来
    HTMLNode *bodyNode = [parser body];
    
    HTMLNode *mainNode = [bodyNode findChildWithAttribute: @"id" matchingName: @"Main" allowPartial: YES];
    
    // 3、获取第一个table
    HTMLNode *firstTableNode = [mainNode findChildTag: @"table"];
    
    // 4、头像
    NSString *icon = nil;
    {
        HTMLNode *avatarNode = [firstTableNode findChildOfClass: @"avatar"];
        icon = [avatarNode getAttributeNamed: @"src"];
        if (icon != nil)
        {
            icon = [WTHTTP stringByAppendingString: icon];
        }
    }
    
    // 5、名称
    NSString *username = nil;
    {
        HTMLNode *h1Node = [firstTableNode findChildTag: @"h1"];
        username = h1Node.allContents;
    }
    
    // 6、加入时间、加入排名、活跃排名
    NSMutableString *joinTime = [NSMutableString string];
    NSMutableString *joinRank = [NSMutableString string];
    NSMutableString *activeRank = [NSMutableString string];
    {
        HTMLNode *grayNode = [firstTableNode findChildOfClass: @"gray"];
        NSString *grayStr = grayNode.allContents;
        NSArray *grayArray = [grayStr componentsSeparatedByString: @"，"];
        NSString *joinRankTemp = grayArray[0];
        NSString *joinTimeTemp = grayArray[1];
        NSString *activeRankTemp = nil;
        if (grayArray.count > 2)
        {
            activeRankTemp = grayArray[2];
        }
        
        // 加入时间
        [joinTimeTemp enumerateRegexMatches: @"\\d{4,}-\\d{2,}-\\d{2,}" options: 0 usingBlock:^(NSString *match, NSRange matchRange, BOOL *stop) {
            [joinTime appendString: match];
            WTLog(@"math:%@", match);
        }];
        
        
        // 加入排名
        [joinRankTemp enumerateRegexMatches: @"\\s\\d*" options: 0 usingBlock:^(NSString *match, NSRange matchRange, BOOL *stop) {
            [joinRank appendString: match];
        }];
        joinRank = [NSMutableString stringWithString: [joinRank stringByReplacingOccurrencesOfString: @" " withString: @""]];
        
        // 活跃排名
        [activeRankTemp enumerateRegexMatches: @"\\d*" options: 0 usingBlock:^(NSString *match, NSRange matchRange, BOOL *stop) {
            [activeRank appendString: match];
        }];
    }
    
    // 7、初始化WTUser，并设置值
    WTUser *user = [WTUser new];
    
    {
        user.icon = [NSURL URLWithString: icon];
        
        user.joinTime = joinTime;
        
        user.joinRank = joinRank;
        
        user.username = username;
        
        user.activeRank = activeRank;
    }
    
    return user;
}


+ (NSMutableArray<WTNotification *> *)getNotificationsWithData:(NSData *)data
{
    /*
     <div class="cell" id="n_3885017">
        <table cellpadding="0" cellspacing="0" border="0" width="100%">
            <tr>
                <td width="32" align="left" valign="top">
                    <a href="/member/yjxjn">
                        <img src="//cdn.v2ex.co/avatar/0190/09b3/100046_normal.png?m=1446318028" class="avatar" border="0" align="default" style="max-width: 24px; max-height: 24px;" />
                    </a>
                </td>
                <td valign="top">
                    <span class="fade">
                        <a href="/member/yjxjn"> <strong>yjxjn</strong></a>
                            在回复
                        <a href="/t/258906#reply24">学习 iOS 的困惑</a>
                            时提到了你
                    </span>
                    &nbsp;
                    <span class="snow">16 小时 4 分钟前 &nbsp;</span>
                    <a href="#;" onclick="deleteNotification(3885017, 38151)" class="node">删除</a>
                    <div class="sep5"></div>
                    <div class="payload">@misaka14 是的。</div>
                </td>
            </tr>
        </table>
    </div>
     */
    
    HTMLParser *parser = [[HTMLParser alloc] initWithData: data error: nil];
    
    // 1、把 html 当中的body部分取出来
    HTMLNode *bodyNode = [parser body];
    
    // 2、查找 class = 'cell'的节点
    HTMLNode *boxNode = [bodyNode findChildOfClass: @"box"];

    // 3、查找 id = 'cell'节点数组
    NSArray *cellNodeArray = [boxNode findChildrenOfClass: @"cell"];
    
    // 4、遍历
    NSMutableArray<WTNotification *> *notifications = [NSMutableArray<WTNotification *> array];
    for (HTMLNode *cellNode in cellNodeArray)
    {
        @autoreleasepool {
            
            // 1、用户名
            NSString *username = nil;
            {
                username = [cellNode findChildTag: @"strong"].allContents;
            }
            
            // 查找 class = 'fade'的节点
            HTMLNode *fadeNode = [cellNode findChildOfClass: @"fade"];
            
            // 2、话题标题
            NSString *title = nil;
            // 3、话题链接
            NSString *topicDetailUrl = nil;
            {
                NSString *fadeContent = fadeNode.allContents;
                
                NSArray *aNodes = [fadeNode findChildTags: @"a"];
                HTMLNode *lastNode = aNodes.lastObject;
                NSString *href = [lastNode getAttributeNamed: @"href"];
                title = fadeContent;
                if (href != nil)
                {
                    topicDetailUrl = [WTHTTPBaseUrl stringByAppendingPathComponent: href];
                }
            }
            
            // 4、时间
            NSString *replyTime = nil;
            {
                HTMLNode *snowNode = [cellNode findChildOfClass: @"snow"];
                replyTime = [snowNode.allContents stringByReplacingOccurrencesOfString: @" " withString: @""];
            }
            
            // 5、回复内容
            NSString *replyContent = nil;
            {
                HTMLNode *payloadNode = [cellNode findChildOfClass: @"payload"];
                replyContent = payloadNode.allContents;
            }
            
            // 查找 td标签的第一个节点
            HTMLNode *tdNode = [cellNode findChildTags: @"td"].firstObject;
            // 6、回复人详情链接
            NSString *replyUserDetailUrl = nil;
            {
                
                HTMLNode *aNode = [tdNode findChildTag: @"a"];
                NSString *href = [aNode getAttributeNamed: @"href"];
                if (href !=  nil)
                {
                    replyUserDetailUrl = [WTHTTPBaseUrl stringByAppendingPathComponent: href];
                }
            }
            
            // 7、回复人的头像
            NSURL *icon = nil;
            {
                HTMLNode *avatarNode = [tdNode findChildOfClass: @"avatar"];
                NSString *src = [avatarNode getAttributeNamed: @"src"];
                if (src != nil)
                {
                    icon = [NSURL URLWithString: [WTHTTP stringByAppendingString: src]];
                }
            }
            
            // 8、创建 WTNotification
            WTNotification *notification = [WTNotification new];
            {
                WTTopic *topic = [WTTopic new];
                topic.title = title;
                topic.detailUrl = topicDetailUrl;
                topic.lastReplyTime = replyTime;
                
                WTUser *user = [WTUser new];
                user.username = username;
                user.detailUrl = replyUserDetailUrl;
                user.icon = icon;
                
                notification.replyContent = replyContent;
                notification.user = user;
                notification.topic = topic;
            }
            
            // 9、添加到数据中
            [notifications addObject: notification];
        }
    }
    // 添加是否有下一页模型
    WTTopic *topic = [WTExtension getIsNextPageWithData: bodyNode];
    WTNotification *notification = [WTNotification new];
    notification.topic = topic;
    [notifications addObject: notification];
    
    return notifications;
}

/**
 *  获取once的值
 */
+ (void)getOnceWithLoginSuccess
{
    [WTHttpTool GETHTML: WTHTTPBaseUrl parameters: nil success:^(id responseObject) {
        
        NSString *html = [[NSString alloc] initWithData: responseObject encoding: NSUTF8StringEncoding];
        
        NSString *once = [NSString subStringWithRegex: @"once=\\d*" string: html];
        once = [NSString subStringWithRegex: @"\\d*" string: once];
        
        [WTAccount shareAccount].once = once;
        
        WTLog(@"getOnceWithLoginSuccess:获取once成功,once:%@", once);
        
    } failure:^(NSError *error) {
        
        WTLog(@"getOnceWithLoginSuccess:获取once失败")
    }];
}
@end