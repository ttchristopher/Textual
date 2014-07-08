/* ********************************************************************* 
       _____        _               _    ___ ____   ____
      |_   _|___  _| |_ _   _  __ _| |  |_ _|  _ \ / ___|
       | |/ _ \ \/ / __| | | |/ _` | |   | || |_) | |
       | |  __/>  <| |_| |_| | (_| | |   | ||  _ <| |___
       |_|\___/_/\_\\__|\__,_|\__,_|_|  |___|_| \_\\____|

 Copyright (c) 2010 — 2014 Codeux Software & respective contributors.
     Please see Acknowledgements.pdf for additional information.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Textual IRC Client & Codeux Software nor the
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

@implementation TPCPreferences (TPCPreferencesCloudSyncExtension)

#ifdef TEXTUAL_BUILT_WITH_ICLOUD_SUPPORT
+ (BOOL)syncPreferencesToTheCloud
{
	return [RZUserDefaults() boolForKey:TPCPreferencesCloudSyncKeyValueStoreServicesDefaultsKey];
}

+ (BOOL)syncPreferencesToTheCloudLimitedToServers
{
	return [RZUserDefaults() boolForKey:TPCPreferencesCloudSyncKeyValueStoreServicesLimitedToServersDefaultsKey];
}
#endif

+ (void)performReloadActionForKeyValues:(NSArray *)prefKeys
{
	#warning Needs to be implemented.
}

+ (void)performReloadActionForActionType:(TPCPreferencesKeyReloadAction)reloadAction
{
	#warning Needs to be implemented.
}

+ (BOOL)performValidationForKeyValues:(BOOL)duringInitialization
{
	/* Validate font. */
	BOOL keyChanged = NO;
	
	if ([NSFont fontIsAvailable:[TPCPreferences themeChannelViewFontName]] == NO) {
		[RZUserDefaults() setObject:TXDefaultTextualChannelViewFont forKey:TPCPreferencesThemeFontNameDefaultsKey];
		
		keyChanged = YES;
	}
	
	/* Validate theme. */
	NSString *activeTheme = [TPCPreferences themeName];
	
	if (duringInitialization == NO) { // themeController is not available during initialization.
		if ([themeController() actualPathForCurrentThemeIsEqualToCachedPath]) {
			return keyChanged;
		} else {
			/* If the path is invalid, but the theme still exists, then its possible
			 it moved from the cloud to the local application support path. */
			if ([TPCThemeController themeExists:activeTheme]) {
				/* If it shows up as still existing, then we just mark it as keyChanged
				 so the controller knows to reload it, but we don't have to do any other
				 checks at this point since we know it just moved somewhere else. */
				keyChanged = YES;
				
				return keyChanged;
			}
		}
	}
	
	/* Continue with normal checks. */
	if ([TPCThemeController themeExists:activeTheme] == NO) {
		NSString *filekind = [TPCThemeController extractThemeSource:activeTheme];
		NSString *filename = [TPCThemeController extractThemeName:activeTheme];
		
		if ([filekind isEqualToString:TPCThemeControllerBundledStyleNameBasicPrefix]) {
			[TPCPreferences setThemeName:TXDefaultTextualChannelViewStyle];
		} else {
			activeTheme = [TPCThemeController buildResourceFilename:filename];
			
			if ([TPCThemeController themeExists:activeTheme]) {
				[TPCPreferences setThemeName:activeTheme];
			} else {
				[TPCPreferences setThemeName:TXDefaultTextualChannelViewStyle];
			}
		}
		
		keyChanged = YES;
	}
	
	return keyChanged;
}

@end
