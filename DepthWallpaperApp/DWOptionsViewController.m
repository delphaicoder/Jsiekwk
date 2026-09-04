#import "DWOptionsViewController.h"
#import "DWPresetManager.h"
#import "../DWShared.h"

@interface DWOptionsViewController () <UITextFieldDelegate>
@property(nonatomic,strong) UISwitch *widgetSwitch;
@property(nonatomic,strong) UITextField *transparencyField;
@property(nonatomic,strong) UILabel *presetCount;
@end

@implementation DWOptionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Options";
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];

    NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
    self.widgetSwitch = [UISwitch new];
    self.widgetSwitch.on = [meta[DWMetaKeyWidgetEnabled] boolValue];
    [self.widgetSwitch addTarget:self action:@selector(widgetChanged) forControlEvents:UIControlEventValueChanged];

    self.transparencyField = [[UITextField alloc] initWithFrame:CGRectMake(0,0,74,36)];
    self.transparencyField.textAlignment = NSTextAlignmentRight;
    self.transparencyField.keyboardType = UIKeyboardTypeNumberPad;
    self.transparencyField.borderStyle = UITextBorderStyleRoundedRect;
    self.transparencyField.placeholder = @"86";
    NSNumber *t = meta[DWMetaKeyWidgetTransparency];
    self.transparencyField.text = t ? [NSString stringWithFormat:@"%ld", (long)MIN(100, MAX(0, t.integerValue))] : @"86";
    self.transparencyField.delegate = self;
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 0, 44)];
    toolbar.items = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneEditingTransparency)]];
    [toolbar sizeToFit];
    self.transparencyField.inputAccessoryView = toolbar;
}

- (void)doneEditingTransparency {
    [self.transparencyField resignFirstResponder];
    [self widgetChanged];
}

- (void)close {
    [self doneEditingTransparency];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 4;
    if (section == 1) return 1;
    if (section == 2) return 5;
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"Depth Presets", @"Diagnostics", @"Lock Screen Widgets", @"About"][section];
}

- (UITableViewCell *)cellForBasic:(UITableView *)tableView title:(NSString *)title detail:(NSString *)detail accessory:(UITableViewCellAccessoryType)accessory {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.detailTextLabel.text = detail;
    cell.accessoryType = accessory;
    return cell;
}

static NSString *DWWidgetTypeName(NSInteger type) {
    switch (type) {
        case 0: return @"Pin";
        case 1: return @"Weather";
        default: return @"Text";
    }
}

static NSString *DWWidgetSlotTypeKey(NSInteger slot) {
    if (slot == 1) return DWMetaKeyWidget1Type;
    if (slot == 2) return DWMetaKeyWidget2Type;
    return DWMetaKeyWidget3Type;
}

static NSString *DWWidgetSlotTextKey(NSInteger slot) {
    if (slot == 1) return DWMetaKeyWidget1Text;
    if (slot == 2) return DWMetaKeyWidget2Text;
    return DWMetaKeyWidget3Text;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section == 0) {
        if (ip.row == 0) return [self cellForBasic:tableView title:@"Lưu preset hiện tại" detail:@"Lưu wallpaper + PNG + vị trí/kích thước" accessory:UITableViewCellAccessoryDisclosureIndicator];
        NSArray *presets = DWPresetManager.sharedManager.presets;
        if (ip.row == 1) return [self cellForBasic:tableView title:@"Chọn preset" detail:[NSString stringWithFormat:@"%ld/20 preset đang lưu", (long)presets.count] accessory:UITableViewCellAccessoryDisclosureIndicator];
        if (ip.row == 2) return [self cellForBasic:tableView title:@"Xóa preset" detail:@"Xóa một preset đã lưu" accessory:UITableViewCellAccessoryDisclosureIndicator];
        return [self cellForBasic:tableView title:@"Preset hiện tại" detail:presets.count ? @"Các file hiện tại vẫn được giữ nguyên" : @"Chưa có preset" accessory:UITableViewCellAccessoryNone];
    }

    if (ip.section == 1) {
        return [self cellForBasic:tableView title:@"Xuất log (.txt)" detail:@"Xuất log chẩn đoán của app" accessory:UITableViewCellAccessoryDisclosureIndicator];
    }

    if (ip.section == 2) {
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
        if (ip.row == 0) {
            UITableViewCell *c = [self cellForBasic:tableView title:@"Widget Lock Screen" detail:@"Bật/tắt cả cụm 3 widget" accessory:UITableViewCellAccessoryNone];
            c.accessoryView = self.widgetSwitch;
            return c;
        }
        if (ip.row >= 1 && ip.row <= 3) {
            NSInteger slot = ip.row;
            NSInteger type = meta[DWWidgetSlotTypeKey(slot)] ? [meta[DWWidgetSlotTypeKey(slot)] integerValue] : (slot == 1 ? 0 : (slot == 2 ? 1 : 2));
            NSString *text = meta[DWWidgetSlotTextKey(slot)] ?: @"";
            NSString *detail = text.length ? [NSString stringWithFormat:@"%@ • %@", DWWidgetTypeName(type), text] : DWWidgetTypeName(type);
            return [self cellForBasic:tableView title:[NSString stringWithFormat:@"Widget %ld", (long)slot] detail:detail accessory:UITableViewCellAccessoryDisclosureIndicator];
        }
        UITableViewCell *c = [self cellForBasic:tableView title:@"Transparency" detail:@"0 = trong suốt, 100 = đậm" accessory:UITableViewCellAccessoryNone];
        c.accessoryView = self.transparencyField;
        return c;
    }

    if (ip.row == 0) return [self cellForBasic:tableView title:@"DepthWallpaper" detail:@"v1.6.5 • Manual Depth + Widgets" accessory:UITableViewCellAccessoryNone];
    return [self cellForBasic:tableView title:@"Cutout engine" detail:@"Giữ nguyên engine ổn định v1.5.6" accessory:UITableViewCellAccessoryNone];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tableView deselectRowAtIndexPath:ip animated:YES];

    if (ip.section == 0 && ip.row == 0) {
        if (DWPresetManager.sharedManager.count >= 20) { [self alert:@"Đã đủ 20 preset. Xóa một preset trước."]; return; }
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Lưu preset" message:@"Đặt tên cho cấu hình hiện tại." preferredStyle:UIAlertControllerStyleAlert];
        [a addTextFieldWithConfigurationHandler:^(UITextField *f){ f.placeholder = @"Ví dụ: Furina blue"; }];
        [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
            NSError *e = nil;
            BOOL ok = [DWPresetManager.sharedManager saveCurrentAsPreset:a.textFields.firstObject.text error:&e];
            [self alert:ok ? @"Đã lưu preset." : (e.localizedDescription ?: @"Không lưu được preset.")];
            [self.tableView reloadData];
        }]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }

    if (ip.section == 0 && (ip.row == 1 || ip.row == 2)) {
        NSArray *presets = DWPresetManager.sharedManager.presets;
        NSMutableArray *actions = [NSMutableArray array];
        for (NSDictionary *p in presets) {
            NSInteger idx = [p[@"index"] integerValue];
            NSString *name = p[@"name"];
            UIAlertAction *act = [UIAlertAction actionWithTitle:name style:(ip.row == 2 ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault) handler:^(UIAlertAction *a){
                NSError *e = nil;
                BOOL ok = ip.row == 2 ? [DWPresetManager.sharedManager deletePreset:idx error:&e] : [DWPresetManager.sharedManager loadPreset:idx error:&e];
                [self alert:ok ? (ip.row == 2 ? @"Đã xóa preset." : @"Đã áp dụng preset.") : (e.localizedDescription ?: @"Thao tác thất bại.")];
                [self.tableView reloadData];
            }];
            [actions addObject:act];
        }
        if (!actions.count) { [self alert:@"Chưa có preset."]; return; }
        UIAlertController *a = [UIAlertController alertControllerWithTitle:(ip.row == 1 ? @"Chọn preset" : @"Xóa preset") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        for (UIAlertAction *x in actions) [a addAction:x];
        [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        UIPopoverPresentationController *popover = a.popoverPresentationController;
        popover.sourceView = self.tableView;
        popover.sourceRect = [self.tableView rectForRowAtIndexPath:ip];
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
        [self presentViewController:a animated:YES completion:nil];
        return;
    }

    if (ip.section == 1 && ip.row == 0) {
        [self exportLogFromIndexPath:ip];
        return;
    }

    if (ip.section == 2 && ip.row >= 1 && ip.row <= 3) {
        [self presentWidgetTypePickerForSlot:ip.row indexPath:ip];
        return;
    }
}

- (void)presentWidgetTypePickerForSlot:(NSInteger)slot indexPath:(NSIndexPath *)ip {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Widget %ld", (long)slot] message:@"Chọn kiểu widget" preferredStyle:UIAlertControllerStyleActionSheet];
    NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
    NSInteger current = meta[DWWidgetSlotTypeKey(slot)] ? [meta[DWWidgetSlotTypeKey(slot)] integerValue] : (slot == 1 ? 0 : (slot == 2 ? 1 : 2));
    NSArray *titles = @[@"Pin", @"Weather", @"Text"];
    for (NSInteger type = 0; type < titles.count; type++) {
        UIAlertActionStyle style = (type == current) ? UIAlertActionStyleDefault : UIAlertActionStyleDefault;
        [a addAction:[UIAlertAction actionWithTitle:titles[type] style:style handler:^(UIAlertAction *x){
            [self saveWidgetSlot:slot type:type text:nil];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = a.popoverPresentationController;
    popover.sourceView = self.tableView;
    popover.sourceRect = [self.tableView rectForRowAtIndexPath:ip];
    popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    [self presentViewController:a animated:YES completion:nil];
}

- (void)saveWidgetSlot:(NSInteger)slot type:(NSInteger)type text:(NSString *)providedText {
    NSMutableDictionary *meta = [NSMutableDictionary dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{}];
    meta[DWWidgetSlotTypeKey(slot)] = @(type);

    NSString *oldText = meta[DWWidgetSlotTextKey(slot)] ?: @"";
    if (type == 0) {
        meta[DWWidgetSlotTextKey(slot)] = @"";
    } else if (providedText) {
        meta[DWWidgetSlotTextKey(slot)] = providedText;
    }

    [meta writeToFile:DWMetadataPath atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), DWReloadNotification, NULL, NULL, YES);
    [self.tableView reloadData];

    if (type != 0 && !providedText) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:type == 1 ? @"Weather" : @"Text" message:type == 1 ? @"Nhập nội dung thời tiết, ví dụ: ☀ 28°C" : @"Nhập nội dung muốn hiển thị" preferredStyle:UIAlertControllerStyleAlert];
        [a addTextFieldWithConfigurationHandler:^(UITextField *f){ f.text = oldText; f.placeholder = type == 1 ? @"☀ 28°C" : @"Nội dung"; }];
        [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
            [self saveWidgetSlot:slot type:type text:a.textFields.firstObject.text ?: @""];
        }]];
        [self presentViewController:a animated:YES completion:nil];
    }
}

- (void)widgetChanged {
    NSMutableDictionary *meta = [NSMutableDictionary dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{}];
    meta[DWMetaKeyWidgetEnabled] = @(self.widgetSwitch.on);
    NSInteger transparency = self.transparencyField.text.length ? self.transparencyField.text.integerValue : 86;
    transparency = MIN(100, MAX(0, transparency));
    self.transparencyField.text = [NSString stringWithFormat:@"%ld", (long)transparency];
    meta[DWMetaKeyWidgetTransparency] = @(transparency);
    [meta writeToFile:DWMetadataPath atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), DWReloadNotification, NULL, NULL, YES);
}

- (void)textFieldDidEndEditing:(UITextField *)textField { [self widgetChanged]; }

- (void)exportLogFromIndexPath:(NSIndexPath *)ip {
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = dir ? [dir stringByAppendingPathComponent:@"DepthWallpaperPicker.log.txt"] : nil;
    if (path && ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSString *fallback = @"DepthWallpaper diagnostic log\nLog file was missing when export was requested.\n";
        [fallback writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    if (!path || ![[NSFileManager defaultManager] fileExistsAtPath:path]) { [self alert:@"Không tìm thấy file log."]; return; }
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    share.popoverPresentationController.sourceView = self.tableView;
    share.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:ip];
    [self presentViewController:share animated:YES completion:nil];
}

- (void)alert:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"DepthWallpaper" message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
