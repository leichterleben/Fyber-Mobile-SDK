//
//  SponsorPaySDK.m
//  SponsorPay iOS SDK
//
//  Created by David Davila on 11/13/12.
//  Copyright (c) 2012 SponsorPay. All rights reserved.
//

#import "SponsorPaySDK.h"
#import "SPAdvertiserManager.h"
#import "SPOfferWallViewController_SDKPrivate.h"
#import "SPVirtualCurrencyServerConnector_SDKPrivate.h"
#import "SPBrandEngageClient_SDKPrivate.h"
#import "SPInterstitialClient.h"
#import "SPInterstitialClient_SDKPrivate.h"
#import "SPCredentialsManager.h"
#import "SPActionIdValidator.h"
#import "SPToast.h"
#import "SPTPNManager.h"
#import "SPRandomID.h"
#import "SPConstants.h"
#import "SPMediationCoordinator.h"
#import "SP_SDK_versions.h"
#import "SPLogger.h"
#import "SPSystemLogger.h"

// Constants used in NSNotifications
NSString *const SPAppIdKey = @"SPAppIdKey";
NSString *const SPUserIdKey = @"SPUserIdKey";

// Keys for SDK configuration per credentials item
static NSString *const SPCurrencyNameConfigKey = @"SPCurrencyNameConfigKey";
static NSString *const SPShowPayoffNotificationConfigKey = @"SPShowPayoffNotificationConfigKey";
static const BOOL SPShowPayoffNotificationConfigDefaultValue = YES;

static NSString *const SPPersistedUserIdKey = @"SponsorPayUserId";

// User feedback message on payoff
static NSString *const SPCoinsNotificationDefaultCurrencyName = @"coins";
static NSString *const SPCoinsNotificationText = @"Congratulations! You've earned %lu %@!";

@interface SponsorPaySDK ()

@property (strong) SPCredentialsManager *credentialsManager;
@property (strong) NSMutableDictionary *brandEngageClientsPool;
@property (strong) NSMutableDictionary *VCSConnectorsPool;
@property (strong) SPMediationCoordinator *mediationCoordinator;

@end

@implementation SponsorPaySDK

#pragma mark - Singleton accessor method and initializer

+ (SponsorPaySDK *)instance
{
    static SponsorPaySDK *instance = NULL;

    @synchronized(self)
    {
        if (instance == NULL)
            instance = [[self alloc] init];
    }

    return (instance);
}

- (id)init
{
    self = [super init];

    if (self) {
        self.credentialsManager = [[SPCredentialsManager alloc] init];
        self.brandEngageClientsPool = [NSMutableDictionary dictionary];
        self.VCSConnectorsPool = [NSMutableDictionary dictionary];
        self.mediationCoordinator = [[SPMediationCoordinator alloc] init];
        [self registerForFeedbackToUserNotifications];
    }

    return self;
}


#pragma mark - Class to unique instance message forwarding

+ (NSString *)startWithAutogeneratedUserForAppId:(NSString *)appId securityToken:(NSString *)securityToken
{
    return [[self instance] startWithAutogeneratedUserForAppId:appId securityToken:securityToken];
}
+ (NSString *)startForAppId:(NSString *)appId userId:(NSString *)userId securityToken:(NSString *)securityToken
{
    return [[self instance] startForAppId:appId userId:userId securityToken:securityToken];
}

+ (SPOfferWallViewController *)offerWallViewController
{
    return [[self instance] offerWallViewController];
}

+ (SPOfferWallViewController *)offerWallViewControllerForCredentials:(NSString *)credentialsToken
{
    return [[self instance] offerWallViewControllerForCredentials:credentialsToken];
}

+ (SPOfferWallViewController *)showOfferWallWithParentViewController:(UIViewController<SPOfferWallViewControllerDelegate> *)parent
{
    return [[self instance] showOfferWallWithParentViewController:parent];
}

+ (SPOfferWallViewController *)showOfferWallWithParentViewController:(UIViewController *)parent
                                                          completion:(OfferWallCompletionBlock)block
{
    return [[self instance] showOfferWallWithParentViewController:parent completion:block];
}

+ (SPBrandEngageClient *)brandEngageClient
{
    return [[self instance] brandEngageClient];
}

+ (SPBrandEngageClient *)brandEngageClientForCredentials:(NSString *)credentialsToken
{
    return [[self instance] brandEngageClientForCredentials:credentialsToken];
}

+ (SPBrandEngageClient *)requestBrandEngageOffersNotifyingDelegate:(id<SPBrandEngageClientDelegate>)delegate
{
    return [[self instance] requestBrandEngageOffersNotifyingDelegate:delegate];
}

+ (SPInterstitialClient *)interstitialClient
{
    return [[self instance] interstitialClient];
}

+ (void)checkInterstitialAvailable:(id<SPInterstitialClientDelegate>)delegate
{
    SPInterstitialClient *client = [[self instance] interstitialClient];
    client.delegate = delegate;

    [client checkInterstitialAvailable];
}

+ (void)showInterstitialFromViewController:(UIViewController *)parentViewController
{
    [[[self instance] interstitialClient] showInterstitialFromViewController:parentViewController];
}

+ (void)setCredentialsForInterstitial:(NSString *)credentials
{
    [[self instance] setCredentialsForInterstitial:credentials];
}

+ (void)setCurrencyName:(NSString *)name
{
    [[self instance] setCurrencyName:name];
}

+ (void)setCurrencyName:(NSString *)name forCredentials:(NSString *)credentialsToken
{
    [[self instance] setCurrencyName:name forCredentials:credentialsToken];
}

+ (NSString *)currencyNameForCredentials:(NSString *)credentialsToken
{
    return [[self instance] currencyNameForCredentials:credentialsToken];
}

+ (void)setShowPayoffNotificationOnVirtualCoinsReceived:(BOOL)shouldShowNotification
{
    [[self instance] setShowPayoffNotificationOnVirtualCoinsReceived:shouldShowNotification];
}

+ (void)setShowPayoffNotificationOnVirtualCoinsReceived:(BOOL)shouldShowNotification
                                         forCredentials:(NSString *)credentialsToken
{
    [[self instance] setShowPayoffNotificationOnVirtualCoinsReceived:shouldShowNotification
                                                      forCredentials:credentialsToken];
}

+ (BOOL)shouldShowPayoffNotificationOnVirtualCoinsReceivedForCredentials:(NSString *)credentialsToken
{
    return [[self instance] shouldShowPayoffNotificationOnVirtualCoinsReceivedForCredentials:credentialsToken];
}

+ (SPVirtualCurrencyServerConnector *)VCSConnector
{
    return [[self instance] VCSConnector];
}

+ (SPVirtualCurrencyServerConnector *)VCSConnectorForCredentials:(NSString *)credentialsToken
{
    return [[self instance] VCSConnectorForCredentials:credentialsToken];
}

+ (SPVirtualCurrencyServerConnector *)requestDeltaOfCoinsNotifyingDelegate:(id<SPVirtualCurrencyConnectionDelegate>)delegate
{
    return [[self instance] requestDeltaOfCoinsNotifyingDelegate:delegate];
}

+ (void)reportActionCompleted:(NSString *)actionID
{
    [[self instance] reportActionCompleted:actionID];
}

+ (void)reportActionCompleted:(NSString *)actionID forCredentials:(NSString *)credentialsToken
{
    [[self instance] reportActionCompleted:actionID forCredentials:credentialsToken];
}

+ (BOOL)isCredentialsTokenValid:(NSString *)credentialsToken
{
    return [[self instance] isCredentialsTokenValid:credentialsToken];
}

+ (NSString *)versionString
{
    return [[self instance] versionString];
}

#pragma mark - Start SDK

- (NSString *)startWithAutogeneratedUserForAppId:(NSString *)appId securityToken:(NSString *)securityToken
{
    NSString *userId = [self anonymousUserId];
    return [self startForAppId:appId userId:userId securityToken:securityToken];
}

- (NSString *)startForAppId:(NSString *)appId userId:(NSString *)userId securityToken:(NSString *)securityToken
{
    // enabling SPSystemLogger by default
    [SPLogger addLogger:[SPSystemLogger logger]];

    if (!userId.length) {
        NSString *exceptionReason = @"No user id could be found. Please specify an user or use "
        @"[startWithAutogeneratedUserForAppId:securityToken:] instead";

        [NSException raise:SPInvalidUserIdException format:@"%@", exceptionReason];
    }

    NSString *credentialsToken = [SPCredentials credentialsTokenForAppId:appId userId:userId];

    SPLogInfo(@"Starting SponsorPay SDK version %@", [self versionString]);
    SPCredentials *credentials = [self.credentialsManager credentialsForToken:credentialsToken];

    if (!credentials) {
        credentials = [SPCredentials credentialsWithAppId:appId userId:userId securityToken:securityToken];

        [self.credentialsManager addCredentialsItem:credentials forToken:credentialsToken];
        [self sendAdvertiserCallbackForCredentials:credentials];
    }

    [self.credentialsManager setCurrentCredentialsWithToken:credentials.credentialsToken];

    credentials.securityToken = securityToken;

    [SPTPNManager startNetworksWithCredentials:credentials];

    return credentialsToken;
}

#pragma mark -

- (void)clearCredentials
{
    [self.credentialsManager clearCredentials];
    SPLogInfo(@"Removed all credential items from SponsorPaySDK");
    [[SPInterstitialClient sharedClient] clearCredentials];
}

#pragma mark - User ID management

- (NSString *)anonymousUserId
{
    NSString *userId = [self persistedUserId];
    if (!userId) {
        userId = [self generatedRandomUserId];
        [self persistUserId:userId];
    }

    return userId;
}

- (NSString *)persistedUserId
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults stringForKey:SPPersistedUserIdKey];
}

- (void)persistUserId:(NSString *)generatedUserId
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:generatedUserId forKey:SPPersistedUserIdKey];
    [defaults synchronize];
}

- (NSString *)generatedRandomUserId
{
    return [SPRandomID randomIDString];
}

- (BOOL)isCredentialsTokenValid:(NSString *)credentialsToken
{
    SPCredentials *credentials = [self.credentialsManager credentialsForToken:credentialsToken];
    return (credentials != nil);
}

#pragma mark - Advertiser callback

- (void)sendAdvertiserCallbackForCredentials:(SPCredentials *)credentials
{
    [[SPAdvertiserManager advertiserManagerForAppId:credentials.appId] reportOfferCompletedWithUserId:credentials.userId];
}

#pragma mark - Currency name

- (void)setCurrencyName:(NSString *)name
{
    [self.credentialsManager setConfigurationValueInAllCredentials:name forKey:SPCurrencyNameConfigKey];
    [self triggerCurrencyNameNotificationWithNewName:name forCredentials:nil];
}

- (void)setCurrencyName:(NSString *)name forCredentials:(NSString *)credentialsToken
{
    SPCredentials *affectedCredentials = [self.credentialsManager setConfigurationValue:name
                                                                                 forKey:SPCurrencyNameConfigKey
                                                                 inCredentialsWithToken:credentialsToken];
    [self triggerCurrencyNameNotificationWithNewName:name forCredentials:affectedCredentials];
}

- (void)triggerCurrencyNameNotificationWithNewName:(NSString *)name forCredentials:(SPCredentials *)credentials
{
    NSDictionary *notificationInfo = @{
        SPNewCurrencyNameKey: name,
        SPAppIdKey: (credentials ? credentials.appId : [NSNull null]),
        SPUserIdKey: (credentials ? credentials.userId : [NSNull null])
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:SPCurrencyNameChangeNotification
                                                        object:self
                                                      userInfo:notificationInfo];
}

- (NSString *)currencyNameForCredentials:(NSString *)credentialsToken
{
    SPCredentials *credentials = [self.credentialsManager credentialsForToken:credentialsToken];
    id currencyName = credentials.userConfig[SPCurrencyNameConfigKey];
    return [currencyName isKindOfClass:[NSString class]] ? currencyName : @"";
}

#pragma mark - Feedback to user

- (void)setShowPayoffNotificationOnVirtualCoinsReceived:(BOOL)shouldShowNotification
{
    [self.credentialsManager setConfigurationValueInAllCredentials:[NSNumber numberWithBool:shouldShowNotification]
                                                            forKey:SPShowPayoffNotificationConfigKey];
}

- (void)setShowPayoffNotificationOnVirtualCoinsReceived:(BOOL)shouldShowNotification
                                         forCredentials:(NSString *)credentialsToken
{
    [self.credentialsManager setConfigurationValue:[NSNumber numberWithBool:shouldShowNotification]
                                            forKey:SPShowPayoffNotificationConfigKey
                            inCredentialsWithToken:credentialsToken];
}

- (BOOL)shouldShowPayoffNotificationOnVirtualCoinsReceivedForCredentials:(NSString *)credentialsToken
{
    SPCredentials *credentials = [self.credentialsManager credentialsForToken:credentialsToken];
    id shouldShowNotification = credentials.userConfig[SPShowPayoffNotificationConfigKey];
    return [shouldShowNotification isKindOfClass:[NSNumber class]] ? [shouldShowNotification boolValue] :
                                                                     SPShowPayoffNotificationConfigDefaultValue;
}

- (void)registerForFeedbackToUserNotifications
{
    SPLogDebug(@"SDK Registering for notification: %@", SPVCSPayoffReceivedNotification);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(vcsPayoffReceived:)
                                                 name:SPVCSPayoffReceivedNotification
                                               object:nil];
}

- (void)vcsPayoffReceived:(NSNotification *)notification
{
    NSDictionary *notificationInfo = notification.userInfo;
    NSString *appId = notificationInfo[SPAppIdKey];
    NSString *userId = notificationInfo[SPUserIdKey];

    SPLogDebug(@"SDK received notification for VCS payoff with userInfo=%@", notificationInfo);

    NSString *credentialsToken = [SPCredentials credentialsTokenForAppId:appId userId:userId];
    SPCredentials *correspondingCredentials = [self.credentialsManager credentialsForToken:credentialsToken];
    if (correspondingCredentials) {
        NSNumber *shouldShowPayoff = correspondingCredentials.userConfig[SPShowPayoffNotificationConfigKey];

        if (!shouldShowPayoff) {
            shouldShowPayoff = [NSNumber numberWithBool:SPShowPayoffNotificationConfigDefaultValue];
        }

        SPLogDebug(@"shouldShowPayoff=%@", shouldShowPayoff);

        if ([shouldShowPayoff boolValue]) {
            id payoffAmount = notificationInfo[SPVCSPayoffAmountKey];
            if ([payoffAmount isKindOfClass:[NSNumber class]]) {
                [self showPayoffNotificationForAmount:[payoffAmount doubleValue]
                                         currencyName:correspondingCredentials.userConfig[SPCurrencyNameConfigKey]];
            } else {
                SPLogError(@"Won't show notification to the user - payoffAmount is not of the correct data type: %@", payoffAmount);
            }
        }
    } else {
        SPLogWarn(@"Won't show notification to the user: credentials are invalid or the SDK has not been started");
    }
}

- (void)showPayoffNotificationForAmount:(double)amount currencyName:(NSString *)explicitCurrencyName
{
    NSUInteger flooredAmount = (NSUInteger)floor(amount);

    BOOL explicitCurrencyNameGiven = (explicitCurrencyName && ![explicitCurrencyName isEqualToString:@""]);

    NSString *currencyName = explicitCurrencyNameGiven ? explicitCurrencyName : SPCoinsNotificationDefaultCurrencyName;

    SPToastSettings *const settings = [SPToastSettings toastSettings];

    settings.duration = SPToastDurationNormal;
    settings.gravity = SPToastGravityBottom;

    (void)[SPToast enqueueToastOfType:SPToastTypeNone
                             withText:[NSString stringWithFormat:SPCoinsNotificationText, (unsigned long)flooredAmount, currencyName]
                             settings:settings];
}

#pragma mark - OfferWall

- (SPOfferWallViewController *)offerWallViewController
{
    return [self offerWallViewControllerForCredentials:[self.credentialsManager currentCredentials].credentialsToken];
}

- (SPOfferWallViewController *)offerWallViewControllerForCredentials:(NSString *)credentialsToken
{
    SPCredentials *credentials = [self.credentialsManager credentialsForToken:credentialsToken];

    SPOfferWallViewController *offerWallVC = [[SPOfferWallViewController alloc] initWithCredentials:credentials];
    offerWallVC.currencyName = credentials.userConfig[SPCurrencyNameConfigKey];

    offerWallVC.disposalBlock = ^(void) {
        SPLogDebug(@"disposing of OfferWall VC");
    };
    
    return offerWallVC;
}

- (SPOfferWallViewController *)showOfferWallWithParentViewController:(UIViewController<SPOfferWallViewControllerDelegate> *)parent
{
    SPOfferWallViewController *offerWallVC = [self offerWallViewController];
    offerWallVC.delegate = parent;

    [offerWallVC showOfferWallWithParentViewController:parent];

    return offerWallVC;
}


- (SPOfferWallViewController *)showOfferWallWithParentViewController:(UIViewController *)parent
                                                          completion:(OfferWallCompletionBlock)block
{
    SPOfferWallViewController *offerWallVC = [self offerWallViewController];
    [offerWallVC showOfferWallWithParentViewController:parent completion:block];

    return offerWallVC;
}


#pragma mark - Mobile BrandEngage

- (SPBrandEngageClient *)brandEngageClient
{
    return [self brandEngageClientForCredentials:[self.credentialsManager currentCredentials].credentialsToken];
}

- (SPBrandEngageClient *)brandEngageClientForCredentials:(NSString *)credentialsToken
{
    SPBrandEngageClient *brandEngageClient = [self.brandEngageClientsPool objectForKey:credentialsToken];

    if (!brandEngageClient) {
        SPCredentials *credentials = [self.credentialsManager credentialsForToken:credentialsToken];
        brandEngageClient = [[SPBrandEngageClient alloc] initWithCredentials:credentials];
        brandEngageClient.currencyName = credentials.userConfig[SPCurrencyNameConfigKey];
        brandEngageClient.mediationCoordinator = self.mediationCoordinator;

        [self.brandEngageClientsPool setObject:brandEngageClient forKey:credentialsToken];
    }

    return brandEngageClient;
}

- (SPBrandEngageClient *)requestBrandEngageOffersNotifyingDelegate:(id<SPBrandEngageClientDelegate>)delegate
{
    SPBrandEngageClient *brandEngageClient = [self brandEngageClient];
    brandEngageClient.delegate = delegate;
    [brandEngageClient requestOffers];

    return brandEngageClient;
}

#pragma mark - Interstitial

- (SPInterstitialClient *)interstitialClient
{
    SPInterstitialClient *interstitialClient = [SPInterstitialClient sharedClient];
    SPCredentials *credentials = [self.credentialsManager currentCredentials];

    [interstitialClient setCredentials:credentials];

    return interstitialClient;
}

- (void)setCredentialsForInterstitial:(NSString *)credentialsToken
{
    SPCredentials *credentials = [self.credentialsManager credentialsForToken:credentialsToken];

    if (credentials) {
        [self.interstitialClient setCredentials:credentials];
    } else {
        SPLogWarn(@"Credentials for Interstitial %@ could not be found", credentialsToken);
    }
}

#pragma mark - VCS

- (SPVirtualCurrencyServerConnector *)VCSConnector
{
    return [self VCSConnectorForCredentials:[self.credentialsManager currentCredentials].credentialsToken];
}

- (SPVirtualCurrencyServerConnector *)VCSConnectorForCredentials:(NSString *)credentialsToken
{
    SPVirtualCurrencyServerConnector *VCSConnector = [self.VCSConnectorsPool objectForKey:credentialsToken];

    SPCredentials *credentials = [self.credentialsManager credentialsForToken:credentialsToken];

    if (!VCSConnector) {
        VCSConnector = [[SPVirtualCurrencyServerConnector alloc] init];
        VCSConnector.appId = credentials.appId;
        VCSConnector.userId = credentials.userId;
        [self.VCSConnectorsPool setObject:VCSConnector forKey:credentialsToken];
    }

    VCSConnector.secretToken = credentials.securityToken;

    return VCSConnector;
}

- (SPVirtualCurrencyServerConnector *)requestDeltaOfCoinsNotifyingDelegate:(id<SPVirtualCurrencyConnectionDelegate>)delegate
{
    SPVirtualCurrencyServerConnector *VCSConnector = [self VCSConnector];
    VCSConnector.delegate = delegate;
    [VCSConnector fetchDeltaOfCoins];

    return VCSConnector;
}


#pragma mark - Rewarded Actions

- (void)reportActionCompleted:(NSString *)actionID
{
    [self reportActionCompleted:actionID forCredentials:[self.credentialsManager currentCredentials].credentialsToken];
}

- (void)reportActionCompleted:(NSString *)actionId forCredentials:(NSString *)credentialsToken
{
    SPCredentials *credentials = [self.credentialsManager credentialsForToken:credentialsToken];

    [SPActionIdValidator validateOrThrow:actionId];

    [[SPAdvertiserManager advertiserManagerForAppId:credentials.appId] reportActionCompleted:actionId];
}

#pragma mark - Misc
- (NSString *)versionString
{
    NSNumber *major = [NSNumber numberWithInteger:SP_SDK_MAJOR_RELEASE_VERSION_NUMBER];
    NSNumber *minor = [NSNumber numberWithInteger:SP_SDK_MINOR_RELEASE_VERSION_NUMBER];
    NSNumber *fix = [NSNumber numberWithInteger:SP_SDK_FIX_RELEASE_VERSION_NUMBER];

    return [NSString stringWithFormat:@"%@.%@.%@",
                                      [major stringValue], // equivalent to descriptionWithLocale:nil, meaning we don't
                                                           // want the description formatted.
                                      [minor stringValue],
                                      [fix stringValue]];
}

+ (void)setLoggingLevel:(SPLogLevel)level
{
    SPLogSetLevel(level);
}

@end