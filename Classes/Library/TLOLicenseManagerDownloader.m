/* ********************************************************************* 
                  _____         _               _
                 |_   _|____  _| |_ _   _  __ _| |
                   | |/ _ \ \/ / __| | | |/ _` | |
                   | |  __/>  <| |_| |_| | (_| | |
                   |_|\___/_/\_\\__|\__,_|\__,_|_|

 Copyright (c) 2010 - 2015 Codeux Software, LLC & respective contributors.
        Please see Acknowledgements.pdf for additional information.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Textual and/or "Codeux Software, LLC", nor the 
      names of its contributors may be used to endorse or promote products 
      derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

 *********************************************************************** */

NS_ASSUME_NONNULL_BEGIN

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1

/* URLs for performing certain actions with license keys. */
NSString * const TLOLicenseManagerDownloaderLicenseAPIActivationURL						= @"https://textual-license-key-backend.codeux.com/activateLicense.cs";
NSString * const TLOLicenseManagerDownloaderLicenseAPIMigrateAppStoreURL				= @"https://textual-license-key-backend.codeux.com/convertReceiptToLicense.cs";
NSString * const TLOLicenseManagerDownloaderLicenseAPISendLostLicenseURL				= @"https://textual-license-key-backend.codeux.com/sendLostLicense.cs";

/* The license API throttles requests to prevent abuse. The following HTTP status 
 code will inform Textual if it the license API has been overwhelmed. */
NSUInteger const TLOLicenseManagerDownloaderRequestHTTPStatusSuccess = 200; // OK
NSUInteger const TLOLicenseManagerDownloaderRequestHTTPStatusTryAgainLater = 503; // Service Unavailable

/* The following constants note status codes that may be returned part of the 
 contents of a license API response body. This is not a complete list. */
NSUInteger const TLOLicenseManagerDownloaderRequestStatusCodeSuccess = 0;

NSUInteger const TLOLicenseManagerDownloaderRequestStatusCodeGenericError = 1000000;
NSUInteger const TLOLicenseManagerDownloaderRequestStatusCodeTryAgainLater = 1000001;

/* Private header */
@interface TLOLicenseManagerDownloaderConnection : NSObject <NSURLConnectionDelegate>
@property (nonatomic, strong) TLOLicenseManagerDownloader *delegate; // To be set by caller
@property (nonatomic, assign) TLOLicenseManagerDownloaderRequestType requestType; // To be set by caller
@property (nonatomic, copy) NSDictionary<NSString *, id> *requestContextInfo; // Information set by caller such as license key or e-mail address
@property (nonatomic, strong) NSURLConnection *requestConnection; // Will be set by the object, readonly
@property (nonatomic, strong) NSHTTPURLResponse *requestResponse; // Will be set by the object, readonly
@property (nonatomic, strong) NSMutableData *requestResponseData; // Will be set by the object, readonly

- (BOOL)setupConnectionRequest;
@end

@interface TLOLicenseManagerDownloader ()
@property (nonatomic, strong, nullable) TLOLicenseManagerDownloaderConnection *activeConnection;

- (void)processResponseForRequestType:(TLOLicenseManagerDownloaderRequestType)requestType httpStatusCode:(NSUInteger)requestHttpStatusCode contents:(NSData *)requestContents;
@end

static BOOL TLOLicenseManagerDownloaderConnectionSelected = NO;

#define _connectionTimeoutInterval			30.0

@implementation TLOLicenseManagerDownloader

#pragma mark -
#pragma mark Public Interface

- (void)activateLicense:(NSString *)licenseKey
{
	NSParameterAssert(licenseKey != nil);

	NSDictionary *contextInfo = @{@"licenseKey" : licenseKey};

	[self setupNewActionWithRequestType:TLOLicenseManagerDownloaderRequestActivationType context:contextInfo];
}

- (void)deactivateLicense
{
	BOOL operationResult = TLOLicenseManagerDeleteUserLicenseFile();

	if (self.completionBlock) {
		self.completionBlock(operationResult);
	}
}

- (void)requestLostLicenseKeyForContactAddress:(NSString *)contactAddress
{
	NSParameterAssert(contactAddress != nil);

	NSDictionary *contextInfo = @{@"licenseOwnerContactAddress" : contactAddress};

	[self setupNewActionWithRequestType:TLOLicenseManagerDownloaderRequestSendLostLicenseType context:contextInfo];
}

- (void)migrateMacAppStorePurcahse:(NSString *)receiptData licenseOwnerName:(NSString *)licenseOwnerName licenseOwnerContactAddress:(NSString *)licenseOwnerContactAddress
{
	NSParameterAssert(receiptData != nil);
	NSParameterAssert(licenseOwnerName != nil);
	NSParameterAssert(licenseOwnerContactAddress != nil);

	NSString *macAddress = [XRSystemInformation formattedEthernetMacAddress];

	NSParameterAssert(macAddress != nil);

	NSDictionary *contextInfo = @{
		@"receiptData" : receiptData,
		@"licenseOwnerName"	: licenseOwnerName,
		@"licenseOwnerContactAddress" : licenseOwnerContactAddress,
		@"licenseOwnerMacAddress" : macAddress
	};

	[self setupNewActionWithRequestType:TLOLicenseManagerDownloaderRequestMigrateAppStoreType context:contextInfo];
}

- (void)setupNewActionWithRequestType:(TLOLicenseManagerDownloaderRequestType)requestType context:(NSDictionary<NSString *, id> *)requestContext
{
	NSParameterAssert(requestContext != nil);

	if (TLOLicenseManagerDownloaderConnectionSelected == NO) {
		TLOLicenseManagerDownloaderConnectionSelected = YES;
	} else {
		return;
	}

	TLOLicenseManagerDownloaderConnection *connectionObject = [TLOLicenseManagerDownloaderConnection new];

	connectionObject.delegate = self;

	connectionObject.requestContextInfo = requestContext;

	connectionObject.requestType = requestType;

	self.activeConnection = connectionObject;

	(void)[connectionObject setupConnectionRequest];
}

- (void)processResponseForRequestType:(TLOLicenseManagerDownloaderRequestType)requestType httpStatusCode:(NSUInteger)requestHttpStatusCode contents:(NSData *)requestContents
{
	/* The license API returns content as property lists, including errors. This method
	 will try to convert the returned contents into an NSDictionary (assuming its a valid
	 property list). If that fails, then the method shows generic failure reason and
	 logs to the console that the contents could not parsed. */

	XRPerformBlockAsynchronouslyOnMainQueue(^{
		self.activeConnection = nil;

		TLOLicenseManagerDownloaderConnectionSelected = NO;
	});

#define _performCompletionBlockAndReturn(operationResult)				if (self.completionBlock) {								\
																			self.completionBlock((operationResult));			\
																		}														\
																																\
																		return;

	/* Attempt to convert contents into a property list dictionary */
	id propertyList = nil;

	if (requestContents) {
		NSError *propertyListReadError = nil;

		propertyList = [NSPropertyListSerialization propertyListWithData:requestContents
																 options:NSPropertyListImmutable
																  format:NULL
																   error:&propertyListReadError];

		if (propertyList == nil || [propertyList isKindOfClass:[NSDictionary class]] == NO) {
			if (propertyListReadError) {
				LogToConsoleError("Failed to convert contents of request into dictionary. Error: %{public}@", [propertyListReadError localizedDescription])
			}
		}
	}

	/* Process resulting property list (if it was successful) */
	if (propertyList) {
		id statusCode = propertyList[@"Status Code"];

		id statusContext = propertyList[@"Status Context"];

		if (statusCode == nil || [statusCode isKindOfClass:[NSNumber class]] == NO) {
			LogToConsoleError("'Status Code' is nil or not of kind 'NSNumber'")

			goto present_fatal_error;
		}

		NSUInteger statusCodeInt = [statusCode unsignedIntegerValue];

		if (requestHttpStatusCode == TLOLicenseManagerDownloaderRequestHTTPStatusSuccess && statusCodeInt == TLOLicenseManagerDownloaderRequestStatusCodeSuccess)
		{
			/* Process successful results */
			if (requestType == TLOLicenseManagerDownloaderRequestActivationType)
			{
				if (statusContext == nil || [statusContext isKindOfClass:[NSData class]] == NO) {
					LogToConsoleError("'Status Context' is nil or not of kind 'NSData'")

					goto present_fatal_error;
				}

				if (TLOLicenseManagerUserLicenseWriteFileContents(statusContext) == NO) {
					LogToConsoleError("Failed to write user license file contents")

					goto present_fatal_error;
				}

				if (self.isSilentOnSuccess == NO) {
					(void)[TLOPopupPrompts dialogWindowWithMessage:TXTLS(@"TLOLicenseManager[1006][2]")
															 title:TXTLS(@"TLOLicenseManager[1006][1]")
													 defaultButton:TXTLS(@"Prompts[0005]")
												   alternateButton:nil];
				}

				_performCompletionBlockAndReturn(YES)
			}
			else if (requestType == TLOLicenseManagerDownloaderRequestSendLostLicenseType)
			{
				if (statusContext == nil || [statusContext isKindOfClass:[NSDictionary class]] == NO) {
					LogToConsoleError("'Status Context' is nil or not of kind 'NSDictionary'")

					goto present_fatal_error;
				}

				NSString *licenseOwnerContactAddress = statusContext[@"licenseOwnerContactAddress"];

				if (NSObjectIsEmpty(licenseOwnerContactAddress)) {
					LogToConsoleError("'licenseOwnerContactAddress' is nil or of zero length")

					goto present_fatal_error;
				}

				if (self.isSilentOnSuccess == NO) {
					(void)[TLOPopupPrompts dialogWindowWithMessage:TXTLS(@"TLOLicenseManager[1005][2]", licenseOwnerContactAddress)
															 title:TXTLS(@"TLOLicenseManager[1005][1]", licenseOwnerContactAddress)
													 defaultButton:TXTLS(@"Prompts[0005]")
												   alternateButton:nil];
				}
				
				_performCompletionBlockAndReturn(YES)
			}
			else if (requestType == TLOLicenseManagerDownloaderRequestMigrateAppStoreType)
			{
				if (statusContext == nil || [statusContext isKindOfClass:[NSDictionary class]] == NO) {
					LogToConsoleError("'Status Context' is nil or not of kind 'NSDictionary'")

					goto present_fatal_error;
				}

				NSString *licenseOwnerContactAddress = statusContext[@"licenseOwnerContactAddress"];

				if (NSObjectIsEmpty(licenseOwnerContactAddress)) {
					LogToConsoleError("'licenseOwnerContactAddress' is nil or of zero length")

					goto present_fatal_error;
				}

				if (self.isSilentOnSuccess == NO) {
					(void)[TLOPopupPrompts dialogWindowWithMessage:TXTLS(@"TLOLicenseManager[1010][2]", licenseOwnerContactAddress)
															 title:TXTLS(@"TLOLicenseManager[1010][1]", licenseOwnerContactAddress)
													 defaultButton:TXTLS(@"Prompts[0005]")
												   alternateButton:nil];
				}

				_performCompletionBlockAndReturn(YES)
			}
		}
		else // TLOLicenseManagerDownloaderRequestStatusCodeSuccess
		{
			/* Errors related to license activation. */
			if (statusCodeInt == 6500000)
			{
				(void)[TLOPopupPrompts dialogWindowWithMessage:TXTLS(@"TLOLicenseManager[1004][2]")
														 title:TXTLS(@"TLOLicenseManager[1004][1]")
												 defaultButton:TXTLS(@"Prompts[0005]")
											   alternateButton:nil];

				_performCompletionBlockAndReturn(NO)
			}
			else if (statusCodeInt == 6500001)
			{
				if (statusContext == nil || [statusContext isKindOfClass:[NSDictionary class]] == NO) {
					LogToConsoleError("'Status Context' kind is not of 'NSDictionary'")

					goto present_fatal_error;
				}

				NSString *licenseKey = statusContext[@"licenseKey"];

				if (NSObjectIsEmpty(licenseKey)) {
					LogToConsoleError("'licenseKey' is nil or of zero length")

					goto present_fatal_error;
				}

				BOOL userResponse = [TLOPopupPrompts dialogWindowWithMessage:TXTLS(@"TLOLicenseManager[1002][2]")
																	   title:TXTLS(@"TLOLicenseManager[1002][1]", licenseKey)
															   defaultButton:TXTLS(@"Prompts[0005]")
															 alternateButton:TXTLS(@"TLOLicenseManager[1002][3]")];

				if (userResponse == NO) { // NO = alternate button
					[self contactSupport];
				}

				_performCompletionBlockAndReturn(NO)
			}
			else if (statusCodeInt == 6500002)
			{
				if (statusContext == nil || [statusContext isKindOfClass:[NSDictionary class]] == NO) {
					LogToConsoleError("'Status Context' kind is not of 'NSDictionary'")

					goto present_fatal_error;
				}

				NSString *licenseKey = statusContext[@"licenseKey"];

				if (NSObjectIsEmpty(licenseKey)) {
					LogToConsoleError("'licenseKey' is nil or of zero length")

					goto present_fatal_error;
				}

				NSInteger licenseKeyActivationLimit = [statusContext integerForKey:@"licenseKeyActivationLimit"];

				(void)[TLOPopupPrompts dialogWindowWithMessage:TXTLS(@"TLOLicenseManager[1014][2]", licenseKeyActivationLimit)
														 title:TXTLS(@"TLOLicenseManager[1014][1]", licenseKey)
												 defaultButton:TXTLS(@"Prompts[0005]")
											   alternateButton:nil];

				_performCompletionBlockAndReturn(NO)
			}

			/* Errors related to lost license recovery. */
			else if (statusCodeInt == 6400000)
			{
				(void)[TLOPopupPrompts dialogWindowWithMessage:TXTLS(@"TLOLicenseManager[1003][2]")
														 title:TXTLS(@"TLOLicenseManager[1003][1]")
												 defaultButton:TXTLS(@"Prompts[0005]")
											   alternateButton:nil];

				_performCompletionBlockAndReturn(NO)
			}
			else if (statusCodeInt == 6400001)
			{
				if (statusContext == nil || [statusContext isKindOfClass:[NSDictionary class]] == NO) {
					LogToConsoleError("'Status Context' kind is not of 'NSDictionary'")

					goto present_fatal_error;
				}

				NSString *originalInput = statusContext[@"originalInput"];

				if (NSObjectIsEmpty(originalInput)) {
					LogToConsoleError("'originalInput' is nil or of zero length")

					goto present_fatal_error;
				}

				(void)[TLOPopupPrompts dialogWindowWithMessage:TXTLS(@"TLOLicenseManager[1013][2]", originalInput)
														 title:TXTLS(@"TLOLicenseManager[1013][1]")
												 defaultButton:TXTLS(@"Prompts[0005]")
											   alternateButton:nil];

				_performCompletionBlockAndReturn(NO)
			}

			/* Error messages related to Mac App Store migration. */
			else if (statusCodeInt == 6600002)
			{
				(void)[TLOPopupPrompts dialogWindowWithMessage:TXTLS(@"TLOLicenseManager[1012][2]")
														 title:TXTLS(@"TLOLicenseManager[1012][1]")
												 defaultButton:TXTLS(@"Prompts[0005]")
											   alternateButton:nil];

				_performCompletionBlockAndReturn(NO)
			}
			else if (statusCodeInt == 6600003)
			{
				/* We do not present a custom dialog for this error, but we still log
				 the contents of the context to the console to help diagnose issues. */
				if (statusContext == nil || [statusContext isKindOfClass:[NSDictionary class]] == NO) {
					LogToConsoleError("'Status Context' kind is not of 'NSDictionary'")

					goto present_fatal_error;
				}

				NSString *errorMessage = statusContext[@"Error Message"];

				if (NSObjectIsEmpty(errorMessage)) {
					LogToConsoleError("'errorMessage' is nil or of zero length")

					goto present_fatal_error;
				}

				LogToConsoleError("Receipt validation failed:\n%{public}@", errorMessage)
			}
			else if (statusCodeInt == 6600004)
			{
				(void)[TLOPopupPrompts dialogWindowWithMessage:TXTLS(@"TLOLicenseManager[1011][2]")
														 title:TXTLS(@"TLOLicenseManager[1011][1]")
												 defaultButton:TXTLS(@"Prompts[0005]")
											   alternateButton:nil];

				_performCompletionBlockAndReturn(NO)
			}
		}
	}

present_fatal_error:
	[self presentTryAgainLaterErrorDialog];

	_performCompletionBlockAndReturn(NO)

#undef _performCompletionBlockAndReturn
}

- (void)presentTryAgainLaterErrorDialog
{
	BOOL userResponse = [TLOPopupPrompts dialogWindowWithMessage:TXTLS(@"TLOLicenseManager[1001][2]")
														   title:TXTLS(@"TLOLicenseManager[1001][1]")
												   defaultButton:TXTLS(@"Prompts[0005]")
												 alternateButton:TXTLS(@"TLOLicenseManager[1001][3]")];

	if (userResponse == NO) { // NO = alternate button
		[self contactSupport];
	}
}

- (void)contactSupport
{
	[TLOpenLink openWithString:@"mailto:support@codeux.com"];
}

@end

#pragma mark -
#pragma mark Connection Assistant

@implementation TLOLicenseManagerDownloaderConnection

- (NSURL *)requestURL
{
	NSString *requestURLString = nil;

	if (self.requestType == TLOLicenseManagerDownloaderRequestActivationType) {
		requestURLString = TLOLicenseManagerDownloaderLicenseAPIActivationURL;
	} else if (self.requestType == TLOLicenseManagerDownloaderRequestSendLostLicenseType) {
		requestURLString = TLOLicenseManagerDownloaderLicenseAPISendLostLicenseURL;
	} else if (self.requestType == TLOLicenseManagerDownloaderRequestMigrateAppStoreType) {
		requestURLString = TLOLicenseManagerDownloaderLicenseAPIMigrateAppStoreURL;
	}

	return [NSURL URLWithString:requestURLString];
}

- (NSString *)encodedRequestContextValue:(NSString *)contextKey
{
	NSParameterAssert(contextKey != nil);

	NSString *contextValue = self.requestContextInfo[contextKey];

	return contextValue.percentEncodedString;
}

- (BOOL)populateRequestPostData:(NSMutableURLRequest *)connectionRequest
{
	NSParameterAssert(connectionRequest != nil);

	/* Post paramater(s) defined by this method are subjec to change at
	 any time because obviously, the license API is not public interface */

	/* Post data is sent as form values with key/value pairs. */
	NSString *currentUserLanguage = [NSLocale currentLocale].localeIdentifier;

	NSString *requestBodyString = nil;

	if (self.requestType == TLOLicenseManagerDownloaderRequestActivationType)
	{
		NSString *encodedContextInfo = [self encodedRequestContextValue:@"licenseKey"];

		requestBodyString = [NSString stringWithFormat:@"licenseKey=%@&lang=%@", encodedContextInfo, currentUserLanguage];
	}
	else if (self.requestType == TLOLicenseManagerDownloaderRequestSendLostLicenseType)
	{
		NSString *encodedContextInfo = [self encodedRequestContextValue:@"licenseOwnerContactAddress"];

		requestBodyString = [NSString stringWithFormat:@"licenseOwnerContactAddress=%@&lang=%@", encodedContextInfo, currentUserLanguage];
	}
	else if (self.requestType == TLOLicenseManagerDownloaderRequestMigrateAppStoreType)
	{
		NSString *receiptData = [self encodedRequestContextValue:@"receiptData"];

		NSString *licenseOwnerName = [self encodedRequestContextValue:@"licenseOwnerName"];

		NSString *licenseOwnerContactAddress = [self encodedRequestContextValue:@"licenseOwnerContactAddress"];

		NSString *licenseOwnerMacAddress = [self encodedRequestContextValue:@"licenseOwnerMacAddress"];

		requestBodyString =
		[NSString stringWithFormat:@"receiptData=%@&licenseOwnerMacAddress=%@&licenseOwnerContactAddress=%@&licenseOwnerName=%@&lang=%@",
				receiptData, licenseOwnerMacAddress, licenseOwnerContactAddress, licenseOwnerName, currentUserLanguage];
	}

	if (requestBodyString == nil) {
		return NO;
	}

	NSData *requestBodyData = [requestBodyString dataUsingEncoding:NSASCIIStringEncoding];

	connectionRequest.HTTPMethod = @"POST";

	[connectionRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

	connectionRequest.HTTPBody = requestBodyData;

	return YES;
}

- (void)dealloc
{
	self.delegate = nil;
}

- (void)destroyConnectionRequest
{
	if ( self.requestConnection) {
		[self.requestConnection cancel];
	}

	self.requestConnection = nil;
	self.requestResponse = nil;
	self.requestResponseData = nil;
}

- (BOOL)setupConnectionRequest
{
	/* Destroy any cached data that may be defined */
	[self destroyConnectionRequest];

	/* Setup request including HTTP POST data. Return NO on failure */
	NSURL *requestURL = [self requestURL];

	if (requestURL == nil) {
		return NO;
	}

	NSMutableURLRequest *baseRequest = [NSMutableURLRequest requestWithURL:requestURL
															   cachePolicy:NSURLRequestReloadIgnoringCacheData
														   timeoutInterval:_connectionTimeoutInterval];

	if ([self populateRequestPostData:baseRequest] == NO) {
		return NO;
	}

	/* Create the connection and start it */
	self.requestResponseData = [NSMutableData data];

	self.requestConnection = [[NSURLConnection alloc] initWithRequest:baseRequest delegate:self startImmediately:NO];

	[self.requestConnection start];

	/* Return a successful result */
	return YES;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSUInteger requestStatusCode = self.requestResponse.statusCode;

	NSData *requestContentsCopy = [self.requestResponseData copy];

	[self destroyConnectionRequest];

	if ( self.delegate) {
		[self.delegate processResponseForRequestType:self.requestType httpStatusCode:requestStatusCode contents:requestContentsCopy];
	}
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self destroyConnectionRequest]; // Destroy the existing request

	LogToConsoleError("Failed to complete connection request with error: %{public}@", [error localizedDescription])

	if ( self.delegate) {
		[self.delegate processResponseForRequestType:self.requestType httpStatusCode:TLOLicenseManagerDownloaderRequestHTTPStatusTryAgainLater contents:nil];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[self.requestResponseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	self.requestResponse = (id)response;
}

- (nullable NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
	return nil;
}

@end

#endif

NS_ASSUME_NONNULL_END
