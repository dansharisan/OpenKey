//
//  ViewController.h
//  ModernKey
//
//  Created by Tuyen on 1/18/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MyTextField.h"

//The settings window. Its views are built in code (loadView), not loaded from Main.storyboard.
@interface ViewController : NSViewController<MyTextFieldDelegate, NSToolbarDelegate>

@property (weak) NSPopUpButton *popupInputType;
@property (weak) NSPopUpButton *popupCode;

@property (weak) NSButton *VietButton;
@property (weak) NSButton *EngButton;

@property (weak) NSButton *UseModernOrthography;

@property (weak) NSButton *CheckSpellingButton;

@property (weak) NSButton *RunOnStartupButton;
@property (weak) NSButton *ShowUIButton;

@property (weak) NSButton *UseGrayIcon;
@property (weak) NSButton *QuickTelex;

@property (weak) NSButton *RestoreIfInvalidWord;
@property (weak) NSButton *FixRecommendBrowser;
@property (weak) NSButton *AllowZWJF;
@property (weak) NSButton *TempOffSpellChecking;

@property (weak) NSButton *UseMacro;
@property (weak) NSButton *UseMacroInEnglishMode;

@property (weak) NSButton *SendKeyStepByStep;
@property (weak) NSButton *AutoRememberSwitchKey;
@property (weak) NSButton *UpperCaseFirstChar;
@property (weak) NSButton *QuickStartConsonant;
@property (weak) NSButton *QuickEndConsonant;

@property (weak) NSButton *RememberTableCode;
@property (weak) NSButton *OtherLanguage;

@property (weak) NSButton *TempOffOpenKey;
@property (weak) NSButton *AutoCapsMacro;
@property (weak) NSButton *ShowIconOnDock;
@property (weak) NSButton *CheckNewVersionOnStartup;
@property (weak) NSButton *FixChromiumBrowser;
@property (weak) NSButton *PerformLayoutCompat;

@property (weak) NSButton *CheckNewVersionButton;
@property (weak) NSTextField *VersionInfo;

-(void)fillData;
@end

