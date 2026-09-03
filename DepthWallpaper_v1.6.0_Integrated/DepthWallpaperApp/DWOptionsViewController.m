#import "DWOptionsViewController.h"
#import "DWPresetManager.h"
#import "../DWShared.h"

@interface DWOptionsViewController ()
@property(nonatomic,strong) UISwitch *widgetSwitch;
@property(nonatomic,strong) UISegmentedControl *widgetType;
@property(nonatomic,strong) UITextField *widgetText;
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
    self.widgetType = [[UISegmentedControl alloc] initWithItems:@[@"Pin", @"Weather", @"Text"]];
    NSInteger type = [meta[DWMetaKeyWidgetType] integerValue];
    self.widgetType.selectedSegmentIndex = MIN(2, MAX(0, type));
    [self.widgetType addTarget:self action:@selector(widgetChanged) forControlEvents:UIControlEventValueChanged];
    self.widgetText = [[UITextField alloc] initWithFrame:CGRectZero];
    self.widgetText.placeholder = @"Ví dụ: ☂ 40% hoặc 27°C";
    self.widgetText.text = meta[DWMetaKeyWidgetText] ?: @"";
    self.widgetText.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.widgetText.delegate = (id<UITextFieldDelegate>)self;
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? 4 : (section == 1 ? 1 : (section == 2 ? 3 : 2)); }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"Depth Presets", @"Diagnostics", @"Lock Screen Widget", @"About"][section];
}

- (UITableViewCell *)cellForBasic:(UITableView *)tableView title:(NSString *)title detail:(NSString *)detail accessory:(UITableViewCellAccessoryType)accessory {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = title; cell.detailTextLabel.text = detail; cell.accessoryType = accessory; return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section == 0) {
        if (ip.row == 0) {
            UITableViewCell *c=[self cellForBasic:tableView title:@"Lưu preset hiện tại" detail:@"Lưu wallpaper + PNG + vị trí/kích thước" accessory:UITableViewCellAccessoryDisclosureIndicator];
            return c;
        }
        NSArray *presets = DWPresetManager.sharedManager.presets;
        if (ip.row == 1) return [self cellForBasic:tableView title:@"Chọn preset" detail:[NSString stringWithFormat:@"%ld/20 preset đang lưu", (long)presets.count] accessory:UITableViewCellAccessoryDisclosureIndicator];
        if (ip.row == 2) return [self cellForBasic:tableView title:@"Xóa preset" detail:@"Xóa một preset đã lưu" accessory:UITableViewCellAccessoryDisclosureIndicator];
        return [self cellForBasic:tableView title:@"Preset hiện tại" detail:presets.count ? @"Các file hiện tại vẫn được giữ nguyên" : @"Chưa có preset" accessory:UITableViewCellAccessoryNone];
    }
    if (ip.section == 1) {
        if (ip.row == 0) return [self cellForBasic:tableView title:@"Xuất log (.txt)" detail:@"DepthWallpaperPicker.log.txt" accessory:UITableViewCellAccessoryDisclosureIndicator];
    }
    if (ip.section == 2) {
        if (ip.row == 0) {
            UITableViewCell *c=[self cellForBasic:tableView title:@"Widget Lock Screen" detail:@"Lớp thử nghiệm, tách khỏi cutout" accessory:UITableViewCellAccessoryNone]; c.accessoryView=self.widgetSwitch; return c;
        }
        if (ip.row == 1) { UITableViewCell *c=[self cellForBasic:tableView title:@"Loại widget" detail:@"Pin = tự cập nhật; Weather = nhập thủ công; Text = tùy ý" accessory:UITableViewCellAccessoryNone]; c.accessoryView=self.widgetType; return c; }
        UITableViewCell *c=[self cellForBasic:tableView title:@"Nội dung" detail:@"Dùng cho Weather/Text" accessory:UITableViewCellAccessoryNone]; c.accessoryView=self.widgetText; return c;
    }
    if (ip.row == 0) return [self cellForBasic:tableView title:@"DepthWallpaper" detail:@"v1.6.0 • Manual Depth" accessory:UITableViewCellAccessoryNone];
    return [self cellForBasic:tableView title:@"Cutout engine" detail:@"Giữ nguyên engine ổn định v1.5.6" accessory:UITableViewCellAccessoryNone];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tableView deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 0 && ip.row == 0) {
        if (DWPresetManager.sharedManager.count >= 20) { [self alert:@"Đã đủ 20 preset. Xóa một preset trước."]; return; }
        UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Lưu preset" message:@"Đặt tên cho cấu hình hiện tại." preferredStyle:UIAlertControllerStyleAlert];
        [a addTextFieldWithConfigurationHandler:^(UITextField *f){ f.placeholder=@"Ví dụ: Furina blue"; }];
        [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){ NSError *e; BOOL ok=[DWPresetManager.sharedManager saveCurrentAsPreset:a.textFields.firstObject.text error:&e]; [self alert:ok?@"Đã lưu preset.":(e.localizedDescription ?: @"Không lưu được preset.")]; [self.tableView reloadData]; }]];
        [self presentViewController:a animated:YES completion:nil];
    } else if (ip.section == 0 && (ip.row == 1 || ip.row == 2)) {
        NSArray *presets=DWPresetManager.sharedManager.presets;
        NSMutableArray *actions=[NSMutableArray array];
        for (NSDictionary *p in presets) {
            NSInteger idx=[p[@"index"] integerValue]; NSString *name=p[@"name"];
            UIAlertAction *act=[UIAlertAction actionWithTitle:name style:(ip.row==2?UIAlertActionStyleDestructive:UIAlertActionStyleDefault) handler:^(UIAlertAction *a){ NSError *e; BOOL ok=ip.row==2?[DWPresetManager.sharedManager deletePreset:idx error:&e]:[DWPresetManager.sharedManager loadPreset:idx error:&e]; [self alert:ok?(ip.row==2?@"Đã xóa preset.":@"Đã áp dụng preset."):(e.localizedDescription ?: @"Thao tác thất bại.")]; [self.tableView reloadData]; }]; [actions addObject:act];
        }
        if (!actions.count) { [self alert:@"Chưa có preset."]; return; }
        UIAlertController *a=[UIAlertController alertControllerWithTitle:(ip.row==1?@"Chọn preset":@"Xóa preset") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        for (UIAlertAction *x in actions) [a addAction:x]; [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]]; [self presentViewController:a animated:YES completion:nil];
    } else if (ip.section == 1 && ip.row == 0) {
        NSString *path=[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject] stringByAppendingPathComponent:@"DepthWallpaperPicker.log.txt"];
        UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil]; share.popoverPresentationController.sourceView=self.view; [self presentViewController:share animated:YES completion:nil];
    }
}

- (void)widgetChanged {
    NSMutableDictionary *meta=[NSMutableDictionary dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{}];
    meta[DWMetaKeyWidgetEnabled]=@(self.widgetSwitch.on); meta[DWMetaKeyWidgetType]=@(self.widgetType.selectedSegmentIndex); meta[DWMetaKeyWidgetText]=self.widgetText.text ?: @"";
    [meta writeToFile:DWMetadataPath atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), DWReloadNotification, NULL, NULL, YES);
}

- (void)textFieldDidEndEditing:(UITextField *)textField { [self widgetChanged]; }
- (void)alert:(NSString *)message { UIAlertController *a=[UIAlertController alertControllerWithTitle:@"DepthWallpaper" message:message preferredStyle:UIAlertControllerStyleAlert]; [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:a animated:YES completion:nil]; }
@end
