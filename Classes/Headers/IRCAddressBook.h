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

#import "TextualApplication.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, IRCAddressBookEntryType) {
	IRCAddressBookIgnoreEntryType = 0,
	IRCAddressBookUserTrackingEntryType
};

typedef NS_ENUM(NSUInteger, IRCAddressBookUserTrackingStatus) {
	IRCAddressBookUserTrackingUnknownStatus = 0,
	IRCAddressBookUserTrackingSignedOffStatus,
	IRCAddressBookUserTrackingSignedOnStatus,
	IRCAddressBookUserTrackingIsAvailalbeStatus,
	IRCAddressBookUserTrackingIsNotAvailalbeStatus,
};

/* Keys that can be accessed by -dictionaryValue. It is recommended to only access
 these keys as any other are used internally and may change without notice. */
TEXTUAL_EXTERN NSString * const IRCAddressBookDictionaryValueIgnoreNoticeMessagesKey;
TEXTUAL_EXTERN NSString * const IRCAddressBookDictionaryValueIgnorePublicMessagesKey;
TEXTUAL_EXTERN NSString * const IRCAddressBookDictionaryValueIgnorePublicMessageHighlightsKey;
TEXTUAL_EXTERN NSString * const IRCAddressBookDictionaryValueIgnorePrivateMessagesKey;
TEXTUAL_EXTERN NSString * const IRCAddressBookDictionaryValueIgnorePrivateMessageHighlightsKey;
TEXTUAL_EXTERN NSString * const IRCAddressBookDictionaryValueIgnoreGeneralEventMessagesKey;
TEXTUAL_EXTERN NSString * const IRCAddressBookDictionaryValueIgnoreFileTransferRequestsKey;
TEXTUAL_EXTERN NSString * const IRCAddressBookDictionaryValueIgnoreClientToClientProtocolKey;

TEXTUAL_EXTERN NSString * const IRCAddressBookDictionaryValueTrackUserActivityKey;

#pragma mark -
#pragma mark Immutable Object

@interface IRCAddressBookEntry : NSObject <NSCopying, NSMutableCopying>
@property (readonly) IRCAddressBookEntryType entryType;
@property (readonly, copy) NSString *uniqueIdentifier;
@property (readonly, copy) NSString *hostmask;
@property (readonly, copy) NSString *hostmaskRegularExpression;
@property (readonly, copy, nullable) NSString *trackingNickname;
@property (readonly) BOOL ignoreClientToClientProtocol;
@property (readonly) BOOL ignoreGeneralEventMessages;
@property (readonly) BOOL ignoreNoticeMessages;
@property (readonly) BOOL ignorePrivateMessageHighlights;
@property (readonly) BOOL ignorePrivateMessages;
@property (readonly) BOOL ignorePublicMessageHighlights;
@property (readonly) BOOL ignorePublicMessages;
@property (readonly) BOOL ignoreFileTransferRequests;
@property (readonly) BOOL ignoreMessagesContainingMatch;
@property (readonly) BOOL trackUserActivity;

+ (instancetype)newIgnoreEntry;
+ (instancetype)newIgnoreEntryForHostmask:(nullable NSString *)hostmask;

+ (instancetype)newUserTrackingEntry;

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dic NS_DESIGNATED_INITIALIZER;
- (NSDictionary<NSString *, id> *)dictionaryValue;

- (id)uniqueCopy;
- (id)uniqueCopyMutable;

- (BOOL)checkMatch:(NSString *)hostmask;
@end

#pragma mark -
#pragma mark Mutable Object

@interface IRCAddressBookEntryMutable : IRCAddressBookEntry
@property (nonatomic, assign, readwrite) IRCAddressBookEntryType entryType;
@property (nonatomic, copy, readwrite) NSString *hostmask;
@property (nonatomic, assign, readwrite) BOOL ignoreClientToClientProtocol;
@property (nonatomic, assign, readwrite) BOOL ignoreGeneralEventMessages;
@property (nonatomic, assign, readwrite) BOOL ignoreNoticeMessages;
@property (nonatomic, assign, readwrite) BOOL ignorePrivateMessageHighlights;
@property (nonatomic, assign, readwrite) BOOL ignorePrivateMessages;
@property (nonatomic, assign, readwrite) BOOL ignorePublicMessageHighlights;
@property (nonatomic, assign, readwrite) BOOL ignorePublicMessages;
@property (nonatomic, assign, readwrite) BOOL ignoreFileTransferRequests;
@property (nonatomic, assign, readwrite) BOOL ignoreMessagesContainingMatch;
@property (nonatomic, assign, readwrite) BOOL trackUserActivity;
@end

NS_ASSUME_NONNULL_END
