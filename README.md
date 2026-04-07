# X岛匿名版鸿蒙客户端 R岛

![HarmonyOS](https://img.shields.io/badge/HarmonyOS-6.0+-blue)
![License](https://img.shields.io/badge/License-MIT-green)

X岛匿名版鸿蒙客户端，为 HarmonyOS 设备提供原生的浏览体验。

## 简介

R岛为 XD 揭示板、X岛揭示板（X岛）的鸿蒙版客户端，以宅文化为主题，类 Futaba 贴图风格的 AcFun 讨论版。

## 关于AppGallery Connect 审核问题

1.您的APP主体非境外主体且服务不在境外，但勾选了“您的APP服务器不在中国大陆”选项，不符合监管部门关于开展APP核准（APP备案）工作的相关要求。
修改建议：请按照《工业和信息化部关于开展移动互联网应用程序备案工作的通知》规定履行核准（备案）手续，并在提交上架申请时正确填写核准（备案）信息。
APP核准（APP备案）要求请参考：
https://www.miit.gov.cn/zwgk/zcwj/wjfb/tz/art/2023/art_920db564162e4312916a01bed6540ad8.html
https://www.miit.gov.cn/zwgk/zcjd/art/2023/art_39b4f1acc36745b98478e0ec3e07128d.html
APP核准（APP备案）FAQ请参考：https://developer.huawei.com/consumer/cn/doc/app/50130
2.您的应用与“X岛揭示板”网站的内容相似，但未提供相关授权证明，可能导致用户产生混淆、误认或不适宜的联想。
修改建议1：请删除与其它应用相同或相似的内容，或提供相关授权证明。并确保授权方名下未上传名称、图标、外观或内容相似的应用。
您可参考《审核指南》第9.5项：https://developer.huawei.com/consumer/cn/doc/app/50104-09
资质审核要求可参考：https://developer.huawei.com/consumer/cn/doc/app/80301
修改建议2：如您认为其他应用侵犯了您的合法权益，可按流程对存疑的侵权内容进行申诉。详细流程可参考：https://developer.huawei.com/consumer/cn/doc/app/50120
3.您应用内“设置”模块展示的开发者名称与在AppGallery Connect上提交的开发者信息不一致，不符合相关法律法规要求。
修改建议：请确保应用内用户协议及各模块展示的应用名称或公司名称与在AppGallery Connect上提交的应用名称及开发者信息保持一致。 
4.您的应用存在功能异常问题，影响用户体验。
测试步骤：1.首页-板块列表-创作线：提示需要饼干才能访问，上滑时，页面闪屏；
2.首页-设置：点击手动，页面展示异常
3.首页-资讯详情页：点击设置-回复，提示：需要登录才能回复，实际无登录入口
4.首页-设置-缓存：点击清除缓存，提示缓存已清空，实际还有54k未清除
测试环境：WIFI、Mate 60、中文
修改建议：请进行优化修复，确保应用可正常使用。
您可参考《审核指南》第3.1项：https://developer.huawei.com/consumer/cn/doc/app/50104-03
5.您的应用【时间线】模块含有违规内容，不符合相关法律法规要求。
修改建议：请删除违规内容。
您可参考《审核指南》第4.5项：https://developer.huawei.com/consumer/cn/doc/app/50104-01
温馨提醒：请构建健全的审查机制，强化内容安全识别。
6.您的应用含有社区模块，具备舆论属性，未提交《安全评估报告》资质证明文件，不符合相关法律法规要求。
修改建议：社区模块需补充提交《安全评估报告》、《安全评估报告》在全国互联网安全服务管理平台的提交结果截图，且现场检查结果为“通过”或审核状态为“审核通过”。
资质审核要求可参考：https://developer.huawei.com/consumer/cn/doc/distribution/app/80301
《安全评估报告》常见问题可参考：https://developer.huawei.com/consumer/cn/doc/50108
WIFI联网、HarmonyOS6.0.0（HUAWEI Mate 60）、简体中文环境。

因此无法上架。肥哥可以自己编译hap文件，或者使用release的hap自己签名载入使用。

## 功能特性

### 核心功能
- 📋 **版块浏览** - 查看所有讨论版块
- 📝 **帖子阅读** - 浏览串内容，支持分页加载
- ⭐ **收藏功能** - 收藏喜欢的串，支持时间线展示
- 🔍 **图片预览** - 支持查看缩放保存
- 📱 **饼干管理** - 扫码/手动添加饼干，支持多账号切换

### 特色功能
- 🌙 **深色主题** - 支持浅色/深色模式切换
- 🔤 **字体设置** - 可调节全局字体大小
- 🎲 **Roll 点显示** - 跑团roll点显示
- ⚡ **性能优化** - 图片缓存、离线阅读支持

## 技术栈

- **框架**: ArkTS
- **依赖库**:
  - `@ohasasugar/hp-richtext` - 富文本渲染,这个还很简陋 OnO
  - `@bigwinepot/cache_manager` - 数据缓存
  - `@ohos/photoview` - 图片缩查看

## 项目结构

```
entry/src/main/ets/
├── api/
│   └── Client.ets          # API 客户端
├── components/
│   ├── PostImage.ets       # 图片组件
│   ├── PostSheet.ets       # 帖子操作面板
│   ├── ReplyItem.ets       # 回复项组件
│   ├── ReplySheet.ets      # 回复面板
│   └── ThreadListItem.ets  # 串列表项
├── entryability/
│   └── EntryAbility.ets    # 应用入口
├── models/
│   ├── Cookie.ets           # 饼干模型
│   ├── Errors.ets          # 错误定义
│   ├── FavoriteThread.ets  # 收藏模型
│   ├── Forum.ets           # 版块模型
│   └── Post.ets            # 帖子模型
├── pages/
│   ├── BoardListPage.ets   # 版块列表页
│   ├── ImagePreviewPage.ets # 图片预览页
│   ├── SettingsPage.ets    # 设置页
│   └── ThreadPage.ets      # 帖子详情页
└── utils/
    ├── CacheManager.ets    # 缓存管理
    ├── CookieManager.ets   # 饼干管理
    ├── FontConfig.ets      # 字体配置
    ├── ImageCacheManager.ets # 图片缓存
    └── SettingsManager.ets # 设置管理
```

## 构建

### 环境要求
- DevEco Studio 6.0.2
- HarmonyOS SDK 6.0.2
- OpenHarmonyApi 20

### 编译运行

1. 克隆项目
```bash
git clone https://github.com/AECBanana/rdnmb.git
```

2. 用 DevEco Studio 打开项目

3. 连接真机或启动模拟器

4. 点击运行 (Run)

## 更新日志

### v20260406.1
- 新增 Roll 点结果显示优化
- 新增字体大小全局设置
- 优化深色主题支持
- 修复若干 bug

## 许可证

MIT License

## 致谢

- [X岛匿名版](https://www.nmbxd1.com)
- [anobbs-client-js](https://github.com/FToovvr/anobbs-client-js)
- [DawnIslandK](https://github.com/yudanhezhongweijie/DawnIslandK)
