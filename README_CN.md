# EchoLink

跨平台 Wi-Fi P2P 通信应用，实现无需任何基站或基础设施的设备间直接通信。

## 功能特性

- **跨平台 P2P 通信**: 同时支持 Android 和 iOS 设备
- **一对一聊天**: 两台设备间的直接消息通信
- **群组通信**: 创建和加入群组，支持多设备通信
- **文件传输**: 发送和接收文件，支持进度追踪
- **自动发现**: 自动发现附近的设备
- **离线通信**: 无需互联网连接

## 通信架构

EchoLink 采用混合通信策略：

| 平台组合 | 技术方案 | 性能 |
|---------|---------|------|
| Android ↔ Android | Wi-Fi Direct (P2P) | 最佳 |
| iOS ↔ iOS | Multipeer Connectivity | 最佳 |
| Android ↔ iOS | Wi-Fi 热点桥接 | 良好 |

## 项目结构

```
echolink/
├── lib/
│   ├── core/                    # 核心基础设施
│   │   ├── constants.dart       # 应用常量
│   │   ├── result.dart          # Result 模式
│   │   ├── exceptions.dart      # 自定义异常
│   │   └── utils/               # 工具类
│   │
│   ├── domain/                  # 领域层
│   │   ├── models/              # 数据模型
│   │   ├── repositories/        # 仓库接口
│   │   └── usecases/            # 业务用例
│   │
│   ├── infrastructure/          # 基础设施层
│   │   ├── network/             # 网络服务
│   │   │   ├── connection_manager.dart
│   │   │   ├── protocols/       # 通信协议
│   │   │   └── platforms/       # 平台特定实现
│   │   ├── storage/             # 本地存储
│   │   └── permissions/         # 权限处理
│   │
│   ├── presentation/            # 表现层
│   │   ├── pages/               # UI 页面
│   │   ├── widgets/             # 可复用组件
│   │   ├── providers/           # 状态管理
│   │   └── theme/               # 应用主题
│   │
│   └── main.dart                # 应用入口
│
├── test/                        # 测试套件
│   ├── unit/
│   ├── widget/
│   └── integration/
│
└── platforms/                   # 平台特定代码
    ├── android/
    └── ios/
```

## 系统要求

- Flutter SDK 3.0.0 或更高版本
- Dart 3.0.0 或更高版本
- Android SDK 21+ (Android 5.0+)
- iOS 12.0+

## 权限要求

### Android
- `ACCESS_FINE_LOCATION` - Wi-Fi P2P 发现所需
- `ACCESS_COARSE_LOCATION` - 位置访问
- `NEARBY_WIFI_DEVICES` - 附近设备发现 (Android 13+)
- `ACCESS_WIFI_STATE` - Wi-Fi 状态访问
- `CHANGE_WIFI_STATE` - Wi-Fi 配置
- `INTERNET` - 网络访问

### iOS
- 本地网络使用权限 - Bonjour 发现所需
- 蓝牙权限 - Multipeer Connectivity 所需

## 安装

1. 克隆仓库：
```bash
git clone https://github.com/yourorg/echolink.git
cd echolink
```

2. 安装依赖：
```bash
flutter pub get
```

3. 运行应用：
```bash
flutter run
```

## 使用方法

### 设备发现
1. 在两台设备上打开应用
2. 在主页点击"发现设备"
3. 等待附近设备出现
4. 点击设备进行连接

### 聊天
1. 首先连接到设备
2. 切换到聊天标签页
3. 输入消息并发送

### 文件传输
1. 首先连接到设备
2. 切换到传输标签页
3. 点击"发送文件"选择文件
4. 在传输列表中查看进度

## 架构设计

EchoLink 遵循 Clean Architecture 原则：

1. **领域层**: 包含业务逻辑、模型和仓库接口
2. **基础设施层**: 实现仓库和平台特定服务
3. **表现层**: UI 组件和状态管理

## 核心组件

### ConnectionManager
管理设备发现、连接建立和数据通道。

### MessageProtocol
高效的消息序列化和传输的二进制协议。

### FileProtocol
分块文件传输，支持进度追踪和校验验证。

### PermissionHandler
跨平台权限请求和验证。

## 测试

运行单元测试：
```bash
flutter test test/unit/
```

运行集成测试：
```bash
flutter test integration_test/
```

## 许可证

本项目采用 GPLv3 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 贡献

欢迎贡献代码！请阅读贡献指南后再提交 Pull Request。

## 支持

如有问题或功能请求，请使用 [GitHub Issues](https://github.com/yourorg/echolink/issues) 页面。