# X岛匿名版鸿蒙客户端 R岛

![HarmonyOS](https://img.shields.io/badge/HarmonyOS-6.0+-blue)
![License](https://img.shields.io/badge/License-MIT-green)

X岛匿名版鸿蒙客户端，为 HarmonyOS 设备提供原生的浏览体验。

## 简介

R岛为 XD 揭示板、X岛揭示板（X岛）的鸿蒙版客户端，以宅文化为主题，类 Futaba 贴图风格的 AcFun 讨论版。

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
