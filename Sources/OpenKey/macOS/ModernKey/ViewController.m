//
//  ViewController.m
//  ModernKey
//
//  Created by Tuyen on 1/18/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//

#import "ViewController.h"
#import "OpenKeyManager.h"
#import "AppDelegate.h"
#import "MyTextField.h"

extern AppDelegate* appDelegate;
extern void OnSpellCheckingChanged(void);

ViewController* viewController;
extern int vFreeMark;
extern int vLanguage;
extern int vCheckSpelling;
extern int vUseModernOrthography;
extern int vSwitchKeyStatus;
extern int vQuickTelex;
extern int vRestoreIfWrongSpelling;
extern int vFixRecommendBrowser;
extern int vUseMacro;
extern int vUseMacroInEnglishMode;
extern int vSendKeyStepByStep;
extern int vUseSmartSwitchKey;
extern int vUpperCaseFirstChar;
extern int vTempOffSpelling;
extern int vAllowConsonantZFWJ;
extern int vQuickStartConsonant;
extern int vQuickEndConsonant;
extern int vRememberCode;
extern int vOtherLanguage;
extern int vTempOffOpenKey;
extern int vShowIconOnDock;
extern int vAutoCapsMacro;
extern int vFixChromiumBrowser;
extern int vPerformLayoutCompat;
extern int ConvertKeyStringToKeyCode(NSString *keyString, CGKeyCode fallback);

//width of every settings pane; the window takes the height of the selected pane
static const CGFloat kPaneWidth = 640;
static const CGFloat kPaneMargin = 24;

//a rounded card behind a group of settings; drawn here so its colours follow light and dark mode
@interface OKCardView : NSView
@end

@implementation OKCardView
- (void)drawRect:(NSRect)dirtyRect {
    NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 0.5, 0.5) xRadius:10 yRadius:10];
    [[[NSColor labelColor] colorWithAlphaComponent:0.05] setFill];
    [path fill];
    [[NSColor separatorColor] setStroke];
    [path stroke];
}
@end

@implementation ViewController {
    NSButton *CustomSwitchCommand;
    NSButton *CustomSwitchOption;
    NSButton *CustomSwitchControl;
    NSButton *CustomSwitchShift;
    MyTextField *CustomSwitchKey;
    NSButton *CustomBeepSound;
    
    NSArray<NSString*>* paneIds;
    NSDictionary<NSString*, NSString*>* paneTitles;
    NSDictionary<NSString*, NSString*>* paneSymbols;
    NSMutableDictionary<NSString*, NSView*>* paneViews; //kept here because only the shown pane is in the window
    NSString* currentPane;
    NSToolbar* toolbar;
}

#pragma mark - Building the settings window

- (void)loadView {
    paneIds = @[@"typing", @"macro", @"apps", @"system", @"about"];
    paneTitles = @{@"typing": @"Bộ gõ", @"macro": @"Gõ tắt", @"apps": @"Ứng dụng", @"system": @"Hệ thống", @"about": @"Thông tin"};
    paneSymbols = @{@"typing": @"keyboard", @"macro": @"text.badge.plus", @"apps": @"macwindow.on.rectangle",
                    @"system": @"gearshape", @"about": @"info.circle"};
    paneViews = [NSMutableDictionary dictionary];
    paneViews[@"typing"] = [self buildTypingPane];
    paneViews[@"macro"] = [self buildMacroPane];
    paneViews[@"apps"] = [self buildAppsPane];
    paneViews[@"system"] = [self buildSystemPane];
    paneViews[@"about"] = [self buildAboutPane];
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, kPaneWidth, 400)];
}

-(NSButton*)checkbox:(NSString*)title action:(SEL)action tip:(NSString*)tip {
    NSButton* button = [NSButton checkboxWithTitle:title target:self action:action];
    button.toolTip = tip;
    return button;
}

//a smaller grey explanation under an option
-(NSTextField*)helpText:(NSString*)text {
    NSTextField* label = [NSTextField wrappingLabelWithString:text];
    label.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    label.textColor = [NSColor secondaryLabelColor];
    label.preferredMaxLayoutWidth = kPaneWidth - 2 * kPaneMargin - 60;
    return label;
}

//an option that only matters when the option above it is on
-(NSView*)indented:(NSArray<NSView*>*)views {
    NSStackView* stack = [NSStackView stackViewWithViews:views];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 8;
    stack.edgeInsets = NSEdgeInsetsMake(0, 22, 0, 0);
    return stack;
}

//a titled group of rows on a rounded card, like System Settings
-(NSView*)section:(NSString*)title rows:(NSArray<NSView*>*)rows {
    NSStackView* inner = [NSStackView stackViewWithViews:rows];
    inner.orientation = NSUserInterfaceLayoutOrientationVertical;
    inner.alignment = NSLayoutAttributeLeading;
    inner.spacing = 12;
    inner.edgeInsets = NSEdgeInsetsMake(14, 16, 14, 16);
    
    OKCardView* card = [[OKCardView alloc] init];
    inner.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:inner];
    [NSLayoutConstraint activateConstraints:@[
        [inner.topAnchor constraintEqualToAnchor:card.topAnchor],
        [inner.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [inner.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [inner.trailingAnchor constraintEqualToAnchor:card.trailingAnchor]]];
    
    NSMutableArray* views = [NSMutableArray array];
    if (title) {
        NSTextField* header = [NSTextField labelWithString:title];
        header.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        [header setAccessibilityRole:NSAccessibilityStaticTextRole];
        [views addObject:header];
    }
    [views addObject:card];
    NSStackView* section = [NSStackView stackViewWithViews:views];
    section.orientation = NSUserInterfaceLayoutOrientationVertical;
    section.alignment = NSLayoutAttributeLeading;
    section.spacing = 6;
    [card.widthAnchor constraintEqualToAnchor:section.widthAnchor].active = YES;
    return section;
}

//the sections of a pane, stacked with room around them
-(NSView*)pane:(NSArray<NSView*>*)sections {
    NSStackView* pane = [NSStackView stackViewWithViews:sections];
    pane.orientation = NSUserInterfaceLayoutOrientationVertical;
    pane.alignment = NSLayoutAttributeLeading;
    pane.spacing = 22;
    pane.edgeInsets = NSEdgeInsetsMake(20, kPaneMargin, kPaneMargin, kPaneMargin);
    pane.translatesAutoresizingMaskIntoConstraints = NO;
    [pane.widthAnchor constraintEqualToConstant:kPaneWidth].active = YES;
    for (NSView* section in sections) {
        [section.widthAnchor constraintEqualToAnchor:pane.widthAnchor constant:-2 * kPaneMargin].active = YES;
    }
    return pane;
}

-(NSTextField*)formLabel:(NSString*)text for:(NSView*)control {
    NSTextField* label = [NSTextField labelWithString:text];
    label.alignment = NSTextAlignmentRight;
    [control setAccessibilityTitleUIElement:label];
    return label;
}

-(NSView*)buildTypingPane {
    //language
    self.VietButton = [NSButton radioButtonWithTitle:@"Tiếng Việt" target:self action:@selector(onLanguageChanged:)];
    self.EngButton = [NSButton radioButtonWithTitle:@"English" target:self action:@selector(onLanguageChanged:)];
    NSStackView* languages = [NSStackView stackViewWithViews:@[self.VietButton, self.EngButton]];
    languages.spacing = 20;
    
    NSPopUpButton* inputType = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [inputType addItemsWithTitles:@[@"Telex", @"VNI", @"Simple Telex 1", @"Simple Telex 2"]];
    inputType.target = self;
    inputType.action = @selector(onInputTypeChanged:);
    [inputType.widthAnchor constraintEqualToConstant:240].active = YES;
    self.popupInputType = inputType;
    
    NSPopUpButton* codeTable = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [codeTable addItemsWithTitles:[OpenKeyManager getTableCodes]];
    codeTable.target = self;
    codeTable.action = @selector(onCodeTableChanged:);
    [codeTable.widthAnchor constraintEqualToConstant:240].active = YES;
    self.popupCode = codeTable;
    
    //switch hotkey: modifiers, an optional key, beep
    CustomSwitchControl = [self checkbox:@"⌃ Control" action:@selector(onControlSwitchKey:) tip:nil];
    CustomSwitchOption = [self checkbox:@"⌥ Option" action:@selector(onOptionSwitchKey:) tip:nil];
    CustomSwitchCommand = [self checkbox:@"⌘ Command" action:@selector(onCommandSwitchKey:) tip:nil];
    CustomSwitchShift = [self checkbox:@"⇧ Shift" action:@selector(onShiftSwitchKey:) tip:nil];
    CustomSwitchKey = [[MyTextField alloc] init];
    CustomSwitchKey.Parent = self;
    CustomSwitchKey.alignment = NSTextAlignmentCenter;
    CustomSwitchKey.placeholderString = @"phím";
    CustomSwitchKey.toolTip = @"Bấm vào đây rồi nhấn một phím";
    [CustomSwitchKey setAccessibilityLabel:@"Phím chuyển chế độ"];
    [CustomSwitchKey.widthAnchor constraintEqualToConstant:64].active = YES;
    NSStackView* modifiers = [NSStackView stackViewWithViews:@[CustomSwitchControl, CustomSwitchOption, CustomSwitchCommand, CustomSwitchShift, CustomSwitchKey]];
    modifiers.spacing = 14;
    CustomBeepSound = [self checkbox:@"Kêu beep khi chuyển chế độ" action:@selector(onBeepSound:) tip:nil];
    NSStackView* hotkey = [NSStackView stackViewWithViews:@[modifiers,
        [self helpText:@"Bấm vào ô phím rồi nhấn một phím. Nhấn Delete để để trống: khi đó chỉ cần nhấn rồi nhả các phím bổ trợ đã chọn, ví dụ ⌃⇧."],
        CustomBeepSound]];
    hotkey.orientation = NSUserInterfaceLayoutOrientationVertical;
    hotkey.alignment = NSLayoutAttributeLeading;
    hotkey.spacing = 8;
    
    NSGridView* form = [NSGridView gridViewWithViews:@[
        @[[self formLabel:@"Chế độ gõ:" for:languages], languages],
        @[[self formLabel:@"Kiểu gõ:" for:inputType], inputType],
        @[[self formLabel:@"Bảng mã:" for:codeTable], codeTable],
        @[[self formLabel:@"Phím chuyển:" for:modifiers], hotkey],
    ]];
    form.rowSpacing = 14;
    form.columnSpacing = 12;
    [form columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;
    form.rowAlignment = NSGridRowAlignmentFirstBaseline;
    
    //spelling and marks
    self.UseModernOrthography = [self checkbox:@"Đặt dấu kiểu mới: oà, uý (thay vì òa, úy)" action:@selector(onModernOrthography:) tip:@"Đặt dấu kiểu cũ và kiểu mới"];
    self.CheckSpellingButton = [self checkbox:@"Kiểm tra chính tả" action:@selector(onCheckSpelling:) tip:@"Tính năng kiểm tra chính tả tương đối, hạn chế gõ sai từ"];
    self.RestoreIfInvalidWord = [self checkbox:@"Tự khôi phục phím với từ sai" action:@selector(onRestoreIfInvalidWord:) tip:@"Từ nào gõ sai với Tiếng Việt thì tự động khôi phục các phím đã gõ"];
    self.AllowZWJF = [self checkbox:@"Cho phép \"z w j f\" làm phụ âm" action:@selector(onAllowZFWJ:) tip:@"Vẫn cho phép gõ các chữ z w j f làm phụ âm đầu khi bật tính năng kiểm tra chính tả"];
    self.TempOffSpellChecking = [self checkbox:@"Tạm tắt chính tả bằng phím ⌃" action:@selector(omTempOffSpellChecking:) tip:@"Tạm tắt kiểm tra chính tả khi gõ một từ nào đó như Đắk Lắk, Krông,..."];
    self.UpperCaseFirstChar = [self checkbox:@"Viết hoa chữ cái đầu câu" action:@selector(onUpperCaseFirstChar:) tip:@"Tự động viết hoa sau dấu chấm ngắt câu và sau khi xuống dòng"];
    
    //temporarily off
    self.TempOffOpenKey = [self checkbox:@"Tạm tắt OpenKey bằng phím ⌘" action:@selector(onTempOffOpenKeyByHotKey:) tip:nil];
    
    return [self pane:@[
        [self section:nil rows:@[form]],
        [self section:@"Dấu và chính tả" rows:@[
            self.UseModernOrthography,
            self.CheckSpellingButton,
            [self indented:@[self.RestoreIfInvalidWord, self.AllowZWJF, self.TempOffSpellChecking]],
            self.UpperCaseFirstChar]],
        [self section:@"Gõ từ tiếng Anh" rows:@[
            self.TempOffOpenKey,
            [self indented:@[[self helpText:@"Chạm ⌘ (nhấn rồi nhả, không kèm phím khác) rồi gõ một từ: từ đó không bị bỏ dấu. Gõ dấu cách là tiếng Việt trở lại."]]]]],
    ]];
}

-(NSView*)buildMacroPane {
    self.UseMacro = [self checkbox:@"Cho phép gõ tắt" action:@selector(onMacroChanged:) tip:@"Bật chế độ gõ tắt để tiết kiệm thời gian gõ"];
    self.UseMacroInEnglishMode = [self checkbox:@"Gõ tắt cả khi tắt gõ tiếng Việt" action:@selector(onUseMacroInEnglishModeChanged:) tip:@"Vẫn có thể gõ tắt khi bạn đang ở chế độ Tiếng Anh"];
    self.AutoCapsMacro = [self checkbox:@"Tự động viết hoa theo phím tắt" action:@selector(onAutoCapsMacro:) tip:@"Ví dụ: gõ tắt btw → by the way thì Btw → By the way, BTW → BY THE WAY"];
    NSButton* macroTable = [NSButton buttonWithTitle:@"Bảng gõ tắt…" target:self action:@selector(onMacroButton:)];
    macroTable.toolTip = @"Thêm, sửa, xoá, nhập và xuất các từ gõ tắt";
    
    self.QuickTelex = [self checkbox:@"Gõ nhanh: cc→ch, gg→gi, kk→kh, nn→ng, qq→qu, pp→ph, tt→th" action:@selector(onQuickTelex:) tip:nil];
    self.QuickStartConsonant = [self checkbox:@"Gõ tắt phụ âm đầu: f→ph, j→gi, w→qu" action:@selector(onQuickStartConsonant:) tip:@"Ví dụ: fải→phải, jảng→giảng"];
    self.QuickEndConsonant = [self checkbox:@"Gõ tắt phụ âm cuối: g→ng, h→nh, k→ch" action:@selector(onQuickEndConsonant:) tip:@"Ví dụ: trươg→trương"];
    
    return [self pane:@[
        [self section:@"Gõ tắt" rows:@[
            self.UseMacro,
            [self indented:@[self.UseMacroInEnglishMode, self.AutoCapsMacro]],
            macroTable]],
        [self section:@"Gõ nhanh" rows:@[self.QuickTelex, self.QuickStartConsonant, self.QuickEndConsonant]],
    ]];
}

-(NSView*)buildAppsPane {
    self.AutoRememberSwitchKey = [self checkbox:@"Nhớ chế độ Anh/Việt theo từng ứng dụng" action:@selector(onAutoRememberSwitchKey:) tip:@"Chuyển chế độ thông minh"];
    self.RememberTableCode = [self checkbox:@"Nhớ bảng mã theo từng ứng dụng" action:@selector(onRememberTableCode:) tip:nil];
    self.OtherLanguage = [self checkbox:@"Tắt tiếng Việt khi bộ gõ của macOS không phải tiếng Anh" action:@selector(onOtherLanguage:) tip:@"Ví dụ khi bạn chuyển sang bộ gõ tiếng Nhật, tiếng Trung"];
    
    self.FixRecommendBrowser = [self checkbox:@"Sửa lỗi gợi ý (trình duyệt, Excel,…)" action:@selector(onFixRecommendBrowser:) tip:@"Sửa lỗi đúp từ trên thanh địa chỉ trình duyệt, Excel,..."];
    self.FixChromiumBrowser = [self checkbox:@"Sửa lỗi trên Chrome, Edge, Brave (thử nghiệm)" action:@selector(onFixChromiumBrowser:) tip:nil];
    self.SendKeyStepByStep = [self checkbox:@"Gửi từng phím" action:@selector(onSendKeyStepByStep:) tip:@"Mặc định nên tắt, với các ứng dụng gặp lỗi thì thử bật tính năng này lên"];
    self.PerformLayoutCompat = [self checkbox:@"Gõ Telex trên bàn phím Dvorak, Colemak,…" action:@selector(onPerformLayoutCompat:) tip:nil];
    
    return [self pane:@[
        [self section:@"Theo ứng dụng" rows:@[self.AutoRememberSwitchKey, self.RememberTableCode, self.OtherLanguage]],
        [self section:@"Tương thích" rows:@[
            self.FixRecommendBrowser,
            [self indented:@[self.FixChromiumBrowser]],
            self.SendKeyStepByStep,
            [self indented:@[[self helpText:@"Chỉ bật khi một ứng dụng gõ sai hoặc mất chữ."]]],
            self.PerformLayoutCompat]],
    ]];
}

-(NSView*)buildSystemPane {
    self.RunOnStartupButton = [self checkbox:@"Khởi động cùng macOS" action:@selector(onRunOnStartup:) tip:@"Tự động chạy chương trình mỗi khi mở máy"];
    self.ShowUIButton = [self checkbox:@"Mở cửa sổ này khi khởi động" action:@selector(onShowUIOnStartup:) tip:nil];
    self.CheckNewVersionOnStartup = [self checkbox:@"Kiểm tra bản mới lúc khởi động" action:@selector(onCheckNewVersionOnStartup:) tip:@"So với bản phát hành chính thức của OpenKey"];
    NSButton* checkNow = [NSButton buttonWithTitle:@"Kiểm tra bản mới…" target:self action:@selector(onCheckNewVersionButton:)];
    self.CheckNewVersionButton = checkNow;
    
    self.UseGrayIcon = [self checkbox:@"Biểu tượng đen trắng trên thanh menu" action:@selector(onGrayIcon:) tip:@"Hợp với giao diện tối"];
    self.ShowIconOnDock = [self checkbox:@"Hiện biểu tượng trên Dock" action:@selector(onShowIconOnDock:) tip:nil];
    
    //reset and quit are far apart and ask nothing in common, so they are hard to hit by mistake
    NSButton* reset = [NSButton buttonWithTitle:@"Khôi phục cài đặt mặc định…" target:self action:@selector(onDefaultConfig:)];
    NSButton* quit = [NSButton buttonWithTitle:@"Thoát OpenKey" target:self action:@selector(onTerminateApp:)];
    NSView* spacer = [[NSView alloc] init];
    [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView* actions = [NSStackView stackViewWithViews:@[reset, spacer, quit]];
    
    NSView* actionsSection = [self section:nil rows:@[actions]];
    [actions.widthAnchor constraintEqualToAnchor:actionsSection.widthAnchor constant:-32].active = YES; //32: the card's insets
    
    return [self pane:@[
        [self section:@"Khởi động" rows:@[self.RunOnStartupButton, self.ShowUIButton, self.CheckNewVersionOnStartup, checkNow]],
        [self section:@"Giao diện" rows:@[self.UseGrayIcon, self.ShowIconOnDock]],
        actionsSection,
    ]];
}

-(NSButton*)linkButton:(NSString*)title action:(SEL)action {
    NSButton* button = [NSButton buttonWithTitle:title target:self action:action];
    button.bordered = NO;
    button.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{
        NSForegroundColorAttributeName: [NSColor linkColor],
        NSFontAttributeName: [NSFont systemFontOfSize:[NSFont systemFontSize]]}];
    return button;
}

-(NSView*)buildAboutPane {
    NSImageView* icon = [NSImageView imageViewWithImage:[NSApp applicationIconImage]];
    [icon.widthAnchor constraintEqualToConstant:72].active = YES;
    [icon.heightAnchor constraintEqualToConstant:72].active = YES;
    
    NSTextField* name = [NSTextField labelWithString:@"OpenKey"];
    name.font = [NSFont systemFontOfSize:20 weight:NSFontWeightSemibold];
    NSTextField* tagline = [NSTextField labelWithString:@"Bộ gõ tiếng Việt nguồn mở, đa nền tảng"];
    NSTextField* version = [NSTextField labelWithString:@""];
    version.textColor = [NSColor secondaryLabelColor];
    version.selectable = YES;
    self.VersionInfo = version;
    self.VersionInfo.stringValue = [NSString stringWithFormat:@"Phiên bản %@ (build %@), ngày build %@",
                                    [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"],
                                    [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"],
                                    [OpenKeyManager getBuildDate]];
    NSStackView* title = [NSStackView stackViewWithViews:@[name, tagline, version]];
    title.orientation = NSUserInterfaceLayoutOrientationVertical;
    title.alignment = NSLayoutAttributeLeading;
    title.spacing = 4;
    NSStackView* header = [NSStackView stackViewWithViews:@[icon, title]];
    header.spacing = 16;
    header.alignment = NSLayoutAttributeCenterY;
    
    NSTextField* fork = [self helpText:@"Bản fork của OpenKey (tác giả Mai Vũ Tuyên), phát hành theo giấy phép GPL v3."];
    NSStackView* links = [NSStackView stackViewWithViews:@[
        [self linkButton:@"Trang chủ OpenKey" action:@selector(onHomePageLink:)],
        [self linkButton:@"Facebook" action:@selector(onFanpageLink:)],
        [self linkButton:@"Mã nguồn bản gốc" action:@selector(onSourceCode:)],
        [self linkButton:@"Mã nguồn bản fork" action:@selector(onForkSourceCode:)]]];
    links.spacing = 18;
    NSStackView* author = [NSStackView stackViewWithViews:@[
        [NSTextField labelWithString:@"Mai Vũ Tuyên © 2019"],
        [self linkButton:@"maivutuyen.91@gmail.com" action:@selector(onEmailLink:)]]];
    author.spacing = 8;
    
    return [self pane:@[
        [self section:nil rows:@[header, fork]],
        [self section:@"Liên kết" rows:@[links, author]],
    ]];
}

#pragma mark - Showing panes

- (void)viewDidLoad {
    [super viewDidLoad];
    viewController = self;
    [self initKey];
    [self fillData];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    [self initKey];
    NSWindow* window = self.view.window;
    if (toolbar == nil && window != nil) {
        toolbar = [[NSToolbar alloc] initWithIdentifier:@"OpenKeySettings"];
        toolbar.delegate = self;
        toolbar.displayMode = NSToolbarDisplayModeIconAndLabel;
        toolbar.allowsUserCustomization = NO;
        window.toolbar = toolbar;
        window.toolbarStyle = NSWindowToolbarStylePreference;
        window.autorecalculatesKeyViewLoop = YES; //Tab moves through every control
        NSString* lastPane = [[NSUserDefaults standardUserDefaults] stringForKey:@"SettingsPane"];
        [self showPane:[paneIds containsObject:lastPane] ? lastPane : paneIds[0] animate:NO];
    }
    //nothing focused on open: a stray key press must not change the switch key
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view.window makeFirstResponder:nil];
    });
}

-(void)initKey {
    dispatch_async(dispatch_get_main_queue(), ^{
        [OpenKeyManager initEventTap];
    });
}

-(void)showPane:(NSString*)paneId animate:(BOOL)animate {
    NSView* pane = paneViews[paneId];
    if (pane == nil)
        return;
    currentPane = paneId;
    [[NSUserDefaults standardUserDefaults] setObject:paneId forKey:@"SettingsPane"];
    for (NSView* view in [self.view.subviews copy]) {
        [view removeFromSuperview];
    }
    [self.view addSubview:pane];
    //below the toolbar, which the content can extend under
    [NSLayoutConstraint activateConstraints:@[
        [pane.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [pane.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [pane.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]]];
    
    NSWindow* window = self.view.window;
    toolbar.selectedItemIdentifier = paneId;
    window.title = paneTitles[paneId];
    
    //resize the window to the pane plus the title bar and toolbar, keeping its top edge in place
    [pane layoutSubtreeIfNeeded];
    NSSize size = pane.fittingSize;
    NSRect oldFrame = window.frame;
    CGFloat chrome = NSHeight(oldFrame) - NSHeight(window.contentLayoutRect);
    NSRect frame = NSMakeRect(NSMinX(oldFrame), NSMaxY(oldFrame) - size.height - chrome, size.width, size.height + chrome);
    [window setFrame:frame display:YES animate:animate];
}

- (void)onToolbarItem:(NSToolbarItem *)sender {
    [self showPane:sender.itemIdentifier animate:YES];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return paneIds;
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return paneIds;
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
    return paneIds;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    item.label = paneTitles[itemIdentifier];
    item.image = [NSImage imageWithSystemSymbolName:paneSymbols[itemIdentifier] accessibilityDescription:paneTitles[itemIdentifier]];
    item.target = self;
    item.action = @selector(onToolbarItem:);
    return item;
}

- (IBAction)onInputTypeChanged:(NSPopUpButton *)sender {
    [appDelegate onInputTypeSelectedIndex:(int)[self.popupInputType indexOfSelectedItem]];
}

- (IBAction)onCodeTableChanged:(NSPopUpButton *)sender {
    [appDelegate onCodeTableChanged:(int)[self.popupCode indexOfSelectedItem]];
}

- (IBAction)onLanguageChanged:(NSButton *)sender {
    //the menu action toggles, so only call it when the other language was chosen
    int language = sender == self.VietButton ? 1 : 0;
    if (language != vLanguage) {
        [appDelegate onInputMethodSelected];
    }
    [self fillData];
}

- (IBAction)onModernOrthography:(NSButton *)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"ModernOrthography"];
    vUseModernOrthography = (int)val;
}

- (IBAction)onCheckSpelling:(NSButton *)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"Spelling"];
    vCheckSpelling = (int)val;
    [self.RestoreIfInvalidWord setEnabled:val];
    [self.AllowZWJF setEnabled:val];
    [self.TempOffSpellChecking setEnabled:val];
    OnSpellCheckingChanged();
}

- (IBAction)onShowUIOnStartup:(NSButton *)sender {
    [self setCustomValue:sender keyToSet:@"ShowUIOnStartup"];
}

- (IBAction)onRunOnStartup:(NSButton *)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"RunOnStartup"];
    [appDelegate setRunOnStartup:val];
}

- (IBAction)onGrayIcon:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"GrayIcon"];
    [appDelegate setGrayIcon:val];
}

- (IBAction)onQuickTelex:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"QuickTelex"];
    vQuickTelex = (int)val;
}

- (IBAction)onRestoreIfInvalidWord:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"RestoreIfInvalidWord"];
    vRestoreIfWrongSpelling = (int)val;
}

- (IBAction)omTempOffSpellChecking:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vTempOffSpelling"];
    vTempOffSpelling = (int)val;
}

- (IBAction)onAllowZFWJ:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vAllowConsonantZFWJ"];
    vAllowConsonantZFWJ = (int)val;
}

- (IBAction)onFixRecommendBrowser:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"FixRecommendBrowser"];
    vFixRecommendBrowser = (int)val;
    [self.FixChromiumBrowser setEnabled:val];
}

- (IBAction)onControlSwitchKey:(NSButton *)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:nil];
    vSwitchKeyStatus &= (~0x100);
    vSwitchKeyStatus |= val << 8;
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
}

- (IBAction)onOptionSwitchKey:(NSButton *)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:nil];
    vSwitchKeyStatus &= (~0x200);
    vSwitchKeyStatus |= val << 9;
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
}

- (IBAction)onCommandSwitchKey:(NSButton *)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:nil];
    vSwitchKeyStatus &= (~0x400);
    vSwitchKeyStatus |= val << 10;
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
}

- (IBAction)onShiftSwitchKey:(NSButton *)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:nil];
    vSwitchKeyStatus &= (~0x800);
    vSwitchKeyStatus |= val << 11;
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
}

-(void)onMyTextFieldKeyChange:(unsigned short)keyCode character:(unsigned short)character {
    if (vPerformLayoutCompat && character != 0) {
        //the event tap compares the QWERTY key code of the typed character
        keyCode = ConvertKeyStringToKeyCode([NSString stringWithFormat:@"%C", (unichar)character], keyCode);
    }
    vSwitchKeyStatus &= 0xFFFFFF00;
    vSwitchKeyStatus |= keyCode;
    vSwitchKeyStatus &= 0x00FFFFFF;
    vSwitchKeyStatus |= ((unsigned int)character<<24);
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
}

- (IBAction)onBeepSound:(NSButton *)sender {
    unsigned int val = (unsigned int)[self setCustomValue:sender keyToSet:nil];
    vSwitchKeyStatus &= (~0x8000);
    vSwitchKeyStatus |= val << 15;
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
}

- (IBAction)onSendKeyStepByStep:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"SendKeyStepByStep"];
    vSendKeyStepByStep = (int)val;
}

- (IBAction)onPerformLayoutCompat:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vPerformLayoutCompat"];
    vPerformLayoutCompat = (int)val;
}

- (NSInteger)setCustomValue:(NSButton*)sender keyToSet:(NSString*) key {
    NSInteger val = 0;
    if (sender.state == NSControlStateValueOn) {
        val = 1;
    } else {
        val = 0;
    }
    if (key != nil)
        [[NSUserDefaults standardUserDefaults] setInteger:val forKey:key];
    return val;
}

- (IBAction)onMacroButton:(id)sender {
    [appDelegate onMacroSelected];
}

- (IBAction)onMacroChanged:(NSButton *)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"UseMacro"];
    vUseMacro = (int)val;
}

- (IBAction)onUseMacroInEnglishModeChanged:(NSButton *)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"UseMacroInEnglishMode"];
    vUseMacroInEnglishMode = (int)val;
}

- (IBAction)onAutoRememberSwitchKey:(NSButton *)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"UseSmartSwitchKey"];
    vUseSmartSwitchKey = (int)val;
}

- (IBAction)onUpperCaseFirstChar:(NSButton *)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"UpperCaseFirstChar"];
    vUpperCaseFirstChar = (int)val;
}
- (IBAction)onQuickStartConsonant:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vQuickStartConsonant"];
    vQuickStartConsonant = (int)val;
}

- (IBAction)onQuickEndConsonant:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vQuickEndConsonant"];
    vQuickEndConsonant = (int)val;
}

- (IBAction)onTempOffOpenKeyByHotKey:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vTempOffOpenKey"];
    vTempOffOpenKey = (int)val;
}

- (IBAction)onRememberTableCode:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vRememberCode"];
    vRememberCode = (int)val;
}
- (IBAction)onOtherLanguage:(id)sender {
    
    NSInteger val = [self setCustomValue:sender keyToSet:@"vOtherLanguage"];
    vOtherLanguage = (int)val;
}


- (IBAction)onAutoCapsMacro:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vAutoCapsMacro"];
    vAutoCapsMacro = (int)val;
}

- (IBAction)onShowIconOnDock:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vShowIconOnDock"];
    vShowIconOnDock = (int)val;
    if (!vShowIconOnDock) {
        [self.view.window close];
    }
    [appDelegate showIconOnDock:vShowIconOnDock];
}

- (IBAction)onCheckNewVersionOnStartup:(NSButton *)sender {
    NSInteger val = sender.state == NSControlStateValueOn ? 0 : 1;
    [[NSUserDefaults standardUserDefaults] setInteger:val forKey:@"DontCheckUpdate"];
}

- (IBAction)onFixChromiumBrowser:(NSButton *)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vFixChromiumBrowser"];
    vFixChromiumBrowser = (int)val;
}

- (IBAction)onTerminateApp:(id)sender {
    [NSApp terminate:0];
}

-(void)fillData {
    NSInteger value;
    
    NSInteger intInputMethod = [[NSUserDefaults standardUserDefaults] integerForKey:@"InputMethod"];
    self.VietButton.state = intInputMethod == 1 ? NSControlStateValueOn : NSControlStateValueOff;
    self.EngButton.state = intInputMethod == 1 ? NSControlStateValueOff : NSControlStateValueOn;
    
    NSInteger intInputType = [[NSUserDefaults standardUserDefaults] integerForKey:@"InputType"];
    [self.popupInputType selectItemAtIndex:intInputType];
    
    NSInteger intCodeTable = [[NSUserDefaults standardUserDefaults] integerForKey:@"CodeTable"];
    [self.popupCode selectItemAtIndex:intCodeTable];
    
    //option
    NSInteger showui = [[NSUserDefaults standardUserDefaults] integerForKey:@"ShowUIOnStartup"];
    self.ShowUIButton.state = showui ? NSControlStateValueOn : NSControlStateValueOff;
    
    NSInteger useModernOrthography = [[NSUserDefaults standardUserDefaults] integerForKey:@"ModernOrthography"];
    self.UseModernOrthography.state = useModernOrthography ? NSControlStateValueOn : NSControlStateValueOff;
    
    NSInteger spelling = [[NSUserDefaults standardUserDefaults] integerForKey:@"Spelling"];
    self.CheckSpellingButton.state = spelling ? NSControlStateValueOn : NSControlStateValueOff;
    
    self.RunOnStartupButton.state = [appDelegate isRunOnStartupEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    
    NSInteger useGrayIcon = [[NSUserDefaults standardUserDefaults] integerForKey:@"GrayIcon"];
    self.UseGrayIcon.state = useGrayIcon ? NSControlStateValueOn : NSControlStateValueOff;
    
    NSInteger quicTelex = [[NSUserDefaults standardUserDefaults] integerForKey:@"QuickTelex"];
    self.QuickTelex.state = quicTelex ? NSControlStateValueOn : NSControlStateValueOff;
    
    NSInteger restoreIfInvalidWord = [[NSUserDefaults standardUserDefaults] integerForKey:@"RestoreIfInvalidWord"];
    self.RestoreIfInvalidWord.state = restoreIfInvalidWord ? NSControlStateValueOn : NSControlStateValueOff;
    [self.RestoreIfInvalidWord setEnabled:spelling];
    
    NSInteger tempOffSpelling = [[NSUserDefaults standardUserDefaults] integerForKey:@"vTempOffSpelling"];
    self.TempOffSpellChecking.state = tempOffSpelling ? NSControlStateValueOn : NSControlStateValueOff;
    [self.TempOffSpellChecking setEnabled:spelling];
    
    NSInteger allowZFWJ = [[NSUserDefaults standardUserDefaults] integerForKey:@"vAllowConsonantZFWJ"];
    self.AllowZWJF.state = allowZFWJ ? NSControlStateValueOn : NSControlStateValueOff;
    [self.AllowZWJF setEnabled:spelling];
    
    NSInteger fixRecommendBrowser = [[NSUserDefaults standardUserDefaults] integerForKey:@"FixRecommendBrowser"];
    self.FixRecommendBrowser.state = fixRecommendBrowser ? NSControlStateValueOn : NSControlStateValueOff;
    
    NSInteger useMacro = [[NSUserDefaults standardUserDefaults] integerForKey:@"UseMacro"];
    self.UseMacro.state = useMacro ? NSControlStateValueOn : NSControlStateValueOff;
    
    NSInteger useMacroInEnglish = [[NSUserDefaults standardUserDefaults] integerForKey:@"UseMacroInEnglishMode"];
    self.UseMacroInEnglishMode.state = useMacroInEnglish ? NSControlStateValueOn : NSControlStateValueOff;
    
    NSInteger sendKeySbS = [[NSUserDefaults standardUserDefaults] integerForKey:@"SendKeyStepByStep"];
    self.SendKeyStepByStep.state = sendKeySbS ? NSControlStateValueOn : NSControlStateValueOff;
    
    NSInteger useSmartSwitchKey = [[NSUserDefaults standardUserDefaults] integerForKey:@"UseSmartSwitchKey"];
    self.AutoRememberSwitchKey.state = useSmartSwitchKey ? NSControlStateValueOn : NSControlStateValueOff;
    
    NSInteger upperCaseFirstChar = [[NSUserDefaults standardUserDefaults] integerForKey:@"UpperCaseFirstChar"];
    self.UpperCaseFirstChar.state = upperCaseFirstChar ? NSControlStateValueOn : NSControlStateValueOff;
    
    NSInteger quickStartConsonant = [[NSUserDefaults standardUserDefaults] integerForKey:@"vQuickStartConsonant"];
    self.QuickStartConsonant.state = quickStartConsonant ? NSControlStateValueOn : NSControlStateValueOff;
    
    NSInteger quickEndConsonant = [[NSUserDefaults standardUserDefaults] integerForKey:@"vQuickEndConsonant"];
    self.QuickEndConsonant.state = quickEndConsonant ? NSControlStateValueOn : NSControlStateValueOff;
    
    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"vRememberCode"];
    self.RememberTableCode.state = value ? NSControlStateValueOn : NSControlStateValueOff;
    
    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"vOtherLanguage"];
    self.OtherLanguage.state = value ? NSControlStateValueOn : NSControlStateValueOff;
    
    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"vTempOffOpenKey"];
    self.TempOffOpenKey.state = value ? NSControlStateValueOn : NSControlStateValueOff;
    
    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"vAutoCapsMacro"];
    self.AutoCapsMacro.state = value ? NSControlStateValueOn : NSControlStateValueOff;
    
    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"vShowIconOnDock"];
    self.ShowIconOnDock.state = value ? NSControlStateValueOn : NSControlStateValueOff;
    
    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"DontCheckUpdate"];
    self.CheckNewVersionOnStartup.state = value ? NSControlStateValueOff :NSControlStateValueOn;
    
    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"vFixChromiumBrowser"];
    self.FixChromiumBrowser.state = value ? NSControlStateValueOn : NSControlStateValueOff;
    self.FixChromiumBrowser.enabled = fixRecommendBrowser ? YES : NO;
    
    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"vPerformLayoutCompat"];
    self.PerformLayoutCompat.state = value ? NSControlStateValueOn : NSControlStateValueOff;
    
    CustomSwitchControl.state = (vSwitchKeyStatus & 0x100) ? NSControlStateValueOn : NSControlStateValueOff;
    CustomSwitchOption.state = (vSwitchKeyStatus & 0x200) ? NSControlStateValueOn : NSControlStateValueOff;
    CustomSwitchCommand.state = (vSwitchKeyStatus & 0x400) ? NSControlStateValueOn : NSControlStateValueOff;
    CustomSwitchShift.state = (vSwitchKeyStatus & 0x800) ? NSControlStateValueOn : NSControlStateValueOff;
    CustomBeepSound.state = (vSwitchKeyStatus & 0x8000) ? NSControlStateValueOn : NSControlStateValueOff;
    [CustomSwitchKey setTextByChar:((vSwitchKeyStatus>>24) & 0xFF)];
    
}

- (IBAction)onOK:(id)sender {
    [self.view.window close];
}

- (IBAction)onDefaultConfig:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Bạn có chắc chắn muốn thiết lập lại cấu hình mặc định?"];
    [alert addButtonWithTitle:@"Có"];
    [alert addButtonWithTitle:@"Không"];
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == 1000) {
            [appDelegate loadDefaultConfig];
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"ShowUIOnStartup"];
            self.ShowUIButton.state = NSControlStateValueOff;
            
            [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"RunOnStartup"];
            self.RunOnStartupButton.state = NSControlStateValueOn;
        }
    }];
}

- (IBAction)onHomePageLink:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"https://open-key.org"]];
}

- (IBAction)onFanpageLink:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"https://www.facebook.com/OpenKeyVN"]];
}

- (IBAction)onEmailLink:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"mailto:maivutuyen.91@gmail.com"]];
}

- (IBAction)onSourceCode:(id)sender {
  [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"https://github.com/tuyenvm/OpenKey"]];
}

- (void)onForkSourceCode:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"https://github.com/dansharisan/OpenKey"]];
}

- (IBAction)onCheckNewVersionButton:(id)sender {
    self.CheckNewVersionButton.title = @"Đang kiểm tra...";
    self.CheckNewVersionButton.enabled = false;
    
    [OpenKeyManager checkNewVersion:self.view.window callbackFunc:^{
        self.CheckNewVersionButton.enabled = true;
        self.CheckNewVersionButton.title = @"Kiểm tra bản mới…";
    }];
}

@end
