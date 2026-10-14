/// 独立模块的宿主边界。宿主只使用入口、页面和通知链接。
library will_mirror;

export 'presentation/module_page.dart'
    show WillMirrorModulePage, WillMirrorDiscoverEntry;
export 'integration/reminders.dart' show MirrorLink;
