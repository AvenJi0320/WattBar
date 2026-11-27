# WattBar 开发规格说明（Spec v0.2）

> 个人 DIY 的 macOS 菜单栏小工具。菜单栏显示一个闪电图标，点开后：
> - 左侧显示**充电功率**
> - 右侧从上到下显示**屏幕功率、电脑功率、外接设备功率**

- 文档日期：2026-11-27
- 开发机：MacBookPro18,1（16 英寸 M1 Pro）/ macOS 27.2.1 / Xcode 27.2 / Swift 6.4.2
- 目标系统：macOS 14+，Apple Silicon MacBook
- 技术栈：Swift 6 + SwiftPM + AppKit（菜单栏外壳）+ SwiftUI（面板）+ IOKit / SMC

---

## 0. 给实现者的硬性规则

本文档会交给其他模型或开发者照着实现。以下规则优先于“看起来更好的做法”。

1. **不要修改公式、SMC 键名或数据优先级。** 实测结果与文档冲突时，先更新本文档的“第 13 节 待验证项”，再改代码。
2. **不引入任何第三方依赖。** 只使用 Foundation、IOKit、AppKit、SwiftUI、ServiceManagement、Observation 和 Swift Testing。
3. **`WattBarCore` 不能 import IOKit、AppKit 或 SwiftUI。** 所有可测试逻辑都放在 Core 中。
4. 非测试代码不能使用 `!` 强制解包，也不能使用 `try!`。
5. 每个 IOKit 对象（`io_service_t`、`io_iterator_t`、`io_connect_t`）都必须对应一次 `IOObjectRelease` 或 `IOServiceClose`。
6. App 内不能调用 `powermetrics`、`sudo`、shell 命令或网络。
7. 每完成第 11 节中的一个步骤，都必须执行 `swift build && swift test`，并且全部通过后再进入下一步。
8. 所有估算值都必须在 UI 上标出来源（见 4.6）。不能把估算值显示成实测值。

---

## 1. 范围

### 1.1 要做

- 菜单栏闪电图标，图标随电源状态切换。
- 点击图标后，在弹出面板中显示：
  - 充电功率
  - 屏幕功率
  - 电脑功率
  - 外接设备功率
  - 底部显示整机功率和适配器输入功率
- 外接设备下方直接平铺列出所有取电设备（不折叠），面板尺寸随内容自适应。
- 右键菜单包含：刷新频率、菜单栏显示数值、登录时启动、退出。
- 提供命令行调试工具 `wattbar-probe`，用于核对原始数据。

### 1.2 不做

- 历史曲线、数据导出、通知、充电上限控制
- Intel Mac 和桌面 Mac（无电池）的适配：检测到这类机器时只显示“不支持”
- 上架、公证、自动更新（个人使用，只做 ad-hoc 签名并在本机运行）

---

## 2. 调研：现有工具怎么算功率

### 2.1 现有工具对比

| 工具 | 整机 / 适配器 | 屏幕 | 外接设备 / 端口 |
|---|---|---|---|
| iStat Menus、FixStat | SMC：`PSTR` 整机、`PDTR` 适配器输入、`PPBR` 电池 | 不单列 | 不单列 |
| macpow | SMC + IOReport | SMC `PDBR` 背光实测（M1–M4） | IORegistry 中的 USB-C `PowerOutDetails`，即 **PD 协商功率** |
| WhatCable / WhatPort | — | — | 按端口取值：支持的机型使用实测遥测，否则使用 **PD 协商合约**，再不行用回退值 |
| 系统信息、`ioreg` | — | — | USB 设备的**分配电流**，例如 `UsbPowerSinkAllocation` |

参考：

- [FixStat](https://lapsely.github.io/fixstat/)
- [macpow](https://github.com/k06a/macpow)
- [macpow 介绍](https://hysenlabs.com/projects/k06a-macpow)
- [WhatCable](https://github.com/darrylmorley/whatcable)
- [WhatCable PortPowerPrecedence.swift](https://gitcode.com/gh_mirrors/wh/whatcable/blob/85871067a72b597f184d7779c398224a77af7f42/Sources/WhatCableCore/Power/PortPowerPrecedence.swift)
- [Stats](https://github.com/exelban/stats)

### 2.2 结论

- 没有任何成熟工具能拿到**外接设备的实际总耗电**。
- 通行做法是**分层取值，并明确标注来源**：
  1. 有实测值时用实测值。
  2. 没有实测值时用 PD 协商功率。
  3. 再没有时用 USB 分配额度。
- WattBar 采用同样的策略，界面上用“实测 / 协商 / 分配”区分。

**重要修正**：屏幕功率**不需要估算**。SMC `PDBR` 可以直接读到背光实测值，开发机实测为 8.34 W。

---

## 3. 数据源（已在开发机实测）

### 3.1 SMC（主数据源，单位：W，类型：`flt `）

| 键 | 含义 | 实测示例 | 用途 |
|---|---|---|---|
| `PSTR` | 整机总功率（System Total） | 26.27 / 32.98 | 总功率主来源 |
| `PDTR` | 适配器 DC 输入功率 | 27.00 / 29.39 | 输入功率主来源 |
| `PDBR` | 内建屏幕背光功率 | 8.34 | 屏幕功率，实测值 |
| `PPBR` | 电池轨功率 | 1.29 | v1 只在 probe 中显示；符号含义待验证 |

读取方式：

- 打开 `AppleSMC` 服务，通过 `IOConnectCallStructMethod(selector = 2)` 读取。
- 结构体大小必须是 80 字节，见 7.1。
- 在 Codex 沙箱内会被拒绝；普通用户运行 App 时可以读取，不需要 root。

### 3.2 AppleSmartBattery（IORegistry）

| 键 | 单位 | 用途 |
|---|---|---|
| `ExternalConnected` / `IsCharging` / `FullyCharged` | Bool | 电源状态 |
| `Voltage` | mV | 电池电压 |
| `InstantAmperage`（缺失时用 `Amperage`） | mA，有符号；正数表示充电，负数表示放电 | 充电或放电功率 |
| `CurrentCapacity` | % | 电量 |
| `AvgTimeToEmpty` | 分钟；65535 表示无效 | 剩余时间 |
| `AdapterDetails.Watts / AdapterVoltage / Current` | W / mV / mA | 适配器规格 |
| `PowerTelemetryData.SystemLoad` | mW | 总功率回退来源 |
| `PowerTelemetryData.SystemPowerIn` | mW | 输入功率回退来源 |
| `PowerTelemetryData.BatteryPower` | mW | 充电功率回退来源 |
| `PowerTelemetryData.AdapterEfficiencyLoss` | mW | 适配器损耗 |
| `ChargerData.NotChargingReason` | Int | 未充电原因；v1 只显示原始值，不翻译 |

开发机实测：

```text
SystemVoltageIn 19769 mV × SystemCurrentIn 1721 mA ≈ 34.0 W
SystemPowerIn = 33907 mW
```

由此确认这些功率字段的单位是 mW。

### 3.3 外接设备相关（IORegistry）

| 来源 | 键 | 含义 | 开发机情况 |
|---|---|---|---|
| USB-C 端口（`AppleTCControllerType10` 等端口服务） | `PortNumber`、`ConnectionActive`、`TransportsActive` | 端口连接状态 | 有 |
| 端口或子节点 | `PowerOutDetails`（`PDPowermW` / `Watts` / `Voltage` + `Current`） | PD 协商的**对外供电功率** | 当前未出现 |
| `IOUSBHostDevice` | `UsbPowerSinkAllocation`（mA，5 V） | USB 设备分配额度 | 有，例如 LAN 350 mA、EarPods 300 mA |

---

## 4. 指标定义与算法

所有功率统一使用 `Double`，单位为 W。

### 4.1 数值有效性

```text
valid(x) = x 是有限值，且 -0.5 <= x <= 500
无效值视为缺失（nil）
-0.5 <= x < 0 时 clamp 为 0
```

### 4.2 数据质量标记

```swift
enum Quality { measured, contracted, allocated, derived, unavailable }
```

### 4.3 各项指标

按顺序使用来源，取第一个有效值：

| 指标 | 来源优先级 | 质量 |
|---|---|---|
| `totalW` 整机 | ① SMC `PSTR` ② `SystemLoad / 1000` ③ 不接电源时 `abs(V × I) / 1e6` | measured |
| `inputW` 输入 | ① SMC `PDTR` ② `SystemPowerIn / 1000`；不接电源时为 0 | measured |
| `adapterLossW` | `AdapterEfficiencyLoss / 1000`；缺失时为 nil | measured |
| `chargeW` 充电 | `I > 0` 时为 `V × I / 1e6`；否则为 0。若 V/I 缺失，用 `max(0, BatteryPower) / 1000` | measured |
| `dischargeW` 放电 | `I < 0` 时为 `abs(V × I) / 1e6`；否则为 0 | measured |
| `displayW` 屏幕 | SMC `PDBR`；缺失时为 nil | measured / unavailable |
| `externalW` 外接 | 见 4.4 | contracted / allocated / measured（确认没有设备时为 0） |
| `computerW` 电脑 | `max(0, totalW − (displayW ?? 0) − (externalW ?? 0))` | derived |

`totalW` 为 nil 时，整个快照的状态为 `unavailable`。

### 4.4 外接设备算法（固定，按此实现）

```text
contracts   = 所有端口上有效 PowerOutDetails 的功率
              每个端口的功率依次取：
              ① PDPowermW / 1000
              ② Watts
              ③ Voltage(mV) × Current(mA) / 1e6

allocations = 所有非内建 IOUSBHostDevice 的 UsbPowerSinkAllocation(mA) × 5 / 1000
              满足以下任一条件即视为内建设备并排除：
              "Built-In" == true
              或 "non-removable" == "yes"
              allocation <= 0 的设备也排除

如果 contracts 非空：
    externalW = Σcontracts
    quality = contracted
否则如果 allocations 非空：
    externalW = Σallocations
    quality = allocated
否则：
    externalW = 0
    quality = measured
    含义：确认没有外接取电设备
```

- 设备列表 `externalDevices` 始终返回所有分配项和所有协商项，供详情页展示。
- 已知局限：分配额度和协商功率都只是上限，实际耗电通常更低。
- v1 不做“USB 设备 → 端口”的归属映射。
- 预留 `ExternalPowerStrategy` 扩展点。以后如果发现可用的 SMC 端口实测键，可以新增一个 `measured` 层，并放在最高优先级。

### 4.5 电源状态

```text
battery == nil                                      → .unsupported
ExternalConnected && I > 0                          → .charging
ExternalConnected && (FullyCharged || I == 0)       → .pluggedIdle   // 已充满或电源直供
ExternalConnected && I < 0                          → .pluggedDraining
!ExternalConnected                                  → .onBattery
```

`.pluggedDraining` 表示虽然接了电源，但电池仍在补电，例如适配器功率不足。

### 4.6 显示格式

- 小于 0.05 W 时显示 `0 W`。
- 小于 100 W 时保留 1 位小数，例如 `12.3 W`。
- 大于或等于 100 W 时显示整数，例如 `112 W`。
- `contracted` 或 `allocated` 时，数字前加 `≈`，右侧显示小标签：`协商` 或 `分配`。
- `unavailable` 时显示 `—`。
- `measured` 和 `derived` 不加前缀。

---

## 5. 系统设计

### 5.1 运行时数据流

```text
┌─────────────── 后台 actor：PowerSampler ───────────────┐
│ SystemPowerReader.read()                               │
│   ├─ SMCClient.readFloat(["PSTR","PDTR","PDBR","PPBR"])│
│   ├─ IORegistry：AppleSmartBattery → BatteryParser     │
│   ├─ IORegistry：USB-C 端口 → PortParser               │
│   └─ USBDeviceCache（事件驱动更新）→ USBDeviceParser    │
│                    ↓ RawReadings（Sendable）            │
└────────────────────┼────────────────────────────────────┘
                     ↓
        PowerDeriver.derive(raw) → PowerSnapshot   （纯函数，Core）
                     ↓
┌─────────────── MainActor：PowerStore（@Observable）─────┐
│ Smoother（EMA）→ displayValues                           │
│ IconState                                               │
└────────┬───────────────────────────────┬────────────────┘
         ↓                               ↓
 StatusItemController（图标、标题）  PowerPanelView（SwiftUI）
```

### 5.2 采样调度

调度逻辑写成纯函数 `SamplingPolicy`，放在 Core 中。

| 活动状态 `Activity` | 采样间隔 |
|---|---|
| `.panelOpen` | 用户设置：1 s（默认）/ 2 s / 5 s |
| `.ambient`：面板关闭，菜单栏显示数值 | 5 s |
| `.idle`：面板关闭，菜单栏不显示数值 | 不轮询（nil） |
| `.suspended`：系统睡眠或屏幕睡眠 | 不轮询（nil） |

会触发重新计算的事件：

- 面板打开或关闭
- 设置变化
- `NSWorkspace.screensDidSleep / screensDidWake / willSleep / didWake`
- 电源插拔事件（`IOPSNotificationCreateRunLoopSource`）

电源插拔事件不受活动状态限制，总会立即采样一次，用于更新图标。

实现方式：

- `PowerStore` 持有一个 `loopTask`。
- 活动状态变化时，取消旧任务并创建新任务。
- 循环中先采样一次，再执行 `clock.sleep(for: interval, tolerance: interval / 10)`。
- `clock` 通过注入传入，测试时使用假时钟。

### 5.3 生命周期

```text
启动：
    NSApplication(.accessory)
    → 创建 StatusItem
    → 采样一次，用于设置图标
    → 注册电源和睡眠通知
    → 进入 .idle 或 .ambient

点击图标：
    创建 NSHostingController
    → 创建无边框 NSPanel（PanelController），定位在菜单栏图标正下方，淡入显示
    → 进入 .panelOpen
    → 立即采样

关闭面板：
    点击面板外任意位置（全局鼠标监听）、切换到其他应用、再次点击图标或右键打开菜单
    → orderOut
    → contentViewController = nil，释放 SwiftUI 树
    → 回到 .idle 或 .ambient

退出：
    取消 loopTask
    → 移除通知
    → SMCClient.close()
    → 释放所有缓存的 io_service_t
```

### 5.4 线程与并发

- 在 Swift 6 严格并发模式下零警告。
- `PowerSampler` 是 actor，所有 IOKit 读取都在这里串行执行。
- `SystemPowerReader` 只由这个 actor 持有；如果需要，可以声明为 `final class ... : @unchecked Sendable`，并加注释说明只被 actor 串行使用。
- `PowerStore`、`StatusItemController` 和 `PanelController` 都是 `@MainActor`。
- 跨边界传递的只有 `RawReadings` 和 `PowerSnapshot`，二者都必须是值类型并且是 `Sendable`。

### 5.5 错误与降级

| 故障 | 行为 |
|---|---|
| SMC 打开失败 | `smc = nil`，所有值走 AppleSmartBattery 回退；probe 打印原因 |
| 某个 SMC 键不存在 | 只把这个键视为 nil；把键信息缓存为“不存在”，以后不再查询 |
| 找不到 AppleSmartBattery | 状态为 `.unsupported`，面板显示“此 Mac 不支持” |
| 单次读取失败 | 保留上一帧数据；连续 3 次 `totalW == nil` 后显示 `—` |
| 系统唤醒 | 丢弃平滑状态，下一帧直接显示原值 |

### 5.6 缓存策略（性能关键）

- `AppleSMC` 连接在启动时打开一次，退出时关闭。
- SMC 每个键的 `KeyInfo`（大小和类型）在第一次查询后缓存。之后每读一个键只需一次 IOKit 调用。
- `AppleSmartBattery` 的 `io_service_t` 缓存起来。只读取第 3.2 节列出的键，不复制整个属性表。
  - 实现时可以使用 `IORegistryEntryCreateCFProperty` 逐个读取。
  - 如果逐个读取的总耗时更高，可以使用一次 `IORegistryEntryCreateCFProperties`，但必须用 probe 的 `--bench` 测量后再决定。
- USB 设备列表通过 `IOServiceAddMatchingNotification` 监听 `IOUSBHostDevice` 的接入和移除，只在变化时重新解析，**不轮询**。
- 端口 `PowerOutDetails` 随每次采样读取。端口数量不超过 4 个，开销很小。

---

## 6. 架构设计

### 6.1 模块与依赖方向

```text
WattBar（App，AppKit + SwiftUI） ─┐
WattBarProbe（CLI）              ─┼─→ WattBarSystem（IOKit 实现）─→ CSMC（C 结构体）
                                 └─→ WattBarCore（纯逻辑，无系统依赖）←─ WattBarSystem
WattBarCoreTests ─→ WattBarCore
```

依赖只能从上往下。`WattBarCore` 只依赖 Foundation。

### 6.2 目录结构

```text
WattBar/
├─ Package.swift
├─ SPEC.md
├─ scripts/
│  ├─ bundle.sh                    // 打包 WattBar.app 并做 ad-hoc 签名
│  ├─ capture-fixtures.sh          // 采集真实 ioreg 数据并脱敏，生成测试 fixture
│  ├─ sanitize-fixture.swift       // fixture 白名单过滤（去除序列号、UUID、进程名）
│  └─ swiftw.sh                    // 在受限沙箱中运行 SwiftPM（缓存重定向到 /tmp）
├─ Sources/
│  ├─ CSMC/
│  │  ├─ include/CSMC.h            // SMC 结构体 + 函数声明
│  │  └─ CSMC.c                    // open / close / keyInfo / read
│  ├─ WattBarCore/
│  │  ├─ Models/RawReadings.swift
│  │  ├─ Models/PowerSnapshot.swift
│  │  ├─ Models/Quality.swift
│  │  ├─ Decoding/FourCC.swift
│  │  ├─ Decoding/SMCDecoder.swift
│  │  ├─ Parsing/RegistryValue.swift      // 从 [String: Any] 安全取值
│  │  ├─ Parsing/BatteryParser.swift
│  │  ├─ Parsing/PortParser.swift
│  │  ├─ Parsing/USBDeviceParser.swift
│  │  ├─ Derivation/PowerDeriver.swift
│  │  ├─ Derivation/ExternalPowerStrategy.swift
│  │  ├─ Derivation/PowerState.swift
│  │  ├─ Presentation/PowerFormatter.swift
│  │  ├─ Presentation/Smoother.swift
│  │  ├─ Presentation/IconState.swift
│  │  └─ Scheduling/SamplingPolicy.swift
│  ├─ WattBarSystem/
│  │  ├─ SMCClient.swift
│  │  ├─ RegistryReader.swift              // IORegistry 封装与释放
│  │  ├─ USBDeviceCache.swift              // 接入/移除通知
│  │  ├─ PowerSourceObserver.swift         // IOPS 插拔通知
│  │  └─ SystemPowerReader.swift           // 组装 RawReadings
│  ├─ WattBar/
│  │  ├─ main.swift
│  │  ├─ AppDelegate.swift
│  │  ├─ PowerStore.swift
│  │  ├─ PowerSampler.swift
│  │  ├─ StatusItemController.swift
│  │  ├─ PanelController.swift          // 无边框 NSPanel：定位、自适应尺寸、点外部关闭
│  │  ├─ SettingsMenu.swift
│  │  ├─ Settings.swift                    // UserDefaults
│  │  └─ UI/
│  │     ├─ PowerPanelView.swift
│  │     ├─ ChargeGaugeView.swift
│  │     ├─ ConsumptionCardView.swift      // 右侧卡片：头部、占比条、三行、设备列表
│  │     ├─ ConsumerRowView.swift
│  │     ├─ StackedBarView.swift
│  │     ├─ ExternalDeviceList.swift
│  │     ├─ FooterView.swift
│  │     └─ Theme.swift
│  └─ WattBarProbe/main.swift
└─ Tests/WattBarCoreTests/
   ├─ Fixtures/                            // .plist，来自 capture-fixtures.sh
   ├─ SMCDecoderTests.swift
   ├─ FourCCTests.swift
   ├─ BatteryParserTests.swift
   ├─ USBDeviceParserTests.swift
   ├─ PortParserTests.swift
   ├─ PowerDeriverTests.swift
   ├─ ExternalPowerStrategyTests.swift
   ├─ PowerStateTests.swift
   ├─ PowerFormatterTests.swift
   ├─ SmootherTests.swift
   ├─ SamplingPolicyTests.swift
   └─ Support/FixtureLoader.swift
```

### 6.3 `Package.swift`

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WattBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "WattBar", targets: ["WattBar"]),
        .executable(name: "wattbar-probe", targets: ["WattBarProbe"]),
    ],
    targets: [
        .target(name: "CSMC", linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "WattBarCore"),
        .target(
            name: "WattBarSystem",
            dependencies: ["WattBarCore", "CSMC"],
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(name: "WattBar", dependencies: ["WattBarCore", "WattBarSystem"]),
        .executableTarget(name: "WattBarProbe", dependencies: ["WattBarCore", "WattBarSystem"]),
        .testTarget(
            name: "WattBarCoreTests",
            dependencies: ["WattBarCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
```

---

## 7. 核心接口（实现时必须保持这些签名）

### 7.1 `CSMC.h`

```c
#pragma once
#include <stdint.h>
#include <IOKit/IOKitLib.h>

typedef struct { uint8_t major, minor, build, reserved; uint16_t release; } SMCVersion;
typedef struct { uint16_t version, length; uint32_t cpuPLimit, gpuPLimit, memPLimit; } SMCPLimitData;
typedef struct { uint32_t dataSize; uint32_t dataType; uint8_t dataAttributes; } SMCKeyInfoData;
typedef struct {
    uint32_t key; SMCVersion vers; SMCPLimitData pLimitData; SMCKeyInfoData keyInfo;
    uint8_t result, status, data8; uint32_t data32; uint8_t bytes[32];
} SMCParamStruct;
_Static_assert(sizeof(SMCParamStruct) == 80, "SMCParamStruct must be 80 bytes");

enum { kSMCHandleYPCEvent = 2, kSMCReadKey = 5, kSMCGetKeyFromIndex = 8, kSMCGetKeyInfo = 9 };

kern_return_t csmc_open(io_connect_t *conn);
void          csmc_close(io_connect_t conn);
kern_return_t csmc_key_info(io_connect_t conn, uint32_t key, SMCKeyInfoData *out);
kern_return_t csmc_read(io_connect_t conn, uint32_t key, SMCKeyInfoData info, uint8_t out[32]);
kern_return_t csmc_key_at_index(io_connect_t conn, uint32_t index, uint32_t *key);
```

`csmc_*` 函数在 `IOConnectCallStructMethod` 失败或 `result != 0` 时返回非 0。

参考实现：

- 使用 `data8 = 9` 查询键信息。
- 使用 `data8 = 5` 读取键值，并设置 `keyInfo.dataSize`。
- 使用 `data8 = 8` 加上 `data32 = index` 枚举键。
- 开发机已经用这套结构读通 2181 个键。

### 7.2 Core 模型

```swift
public struct SMCPowerReadings: Sendable, Equatable {
    public var systemTotalW: Double?   // PSTR
    public var dcInW: Double?          // PDTR
    public var backlightW: Double?     // PDBR
    public var batteryRailW: Double?   // PPBR
}

public struct BatteryTelemetry: Sendable, Equatable {
    public var systemLoadMW: Int?
    public var systemPowerInMW: Int?
    public var batteryPowerMW: Int?
    public var adapterLossMW: Int?
}

public struct BatteryReadings: Sendable, Equatable {
    public var externalConnected: Bool
    public var isCharging: Bool
    public var fullyCharged: Bool
    public var voltageMV: Int?
    public var amperageMA: Int?        // 有符号，已处理 64 位补码
    public var percent: Int?
    public var timeToEmptyMin: Int?    // 65535 → nil
    public var adapterWatts: Int?
    public var adapterVoltageMV: Int?
    public var adapterCurrentMA: Int?
    public var telemetry: BatteryTelemetry?
    public var notChargingReason: Int?
}

public struct PortReading: Sendable, Equatable {
    public var portNumber: Int
    public var connectionActive: Bool
    public var transports: [String]
    public var powerOutW: Double?      // 按 4.4 优先级解析出的 PD 协商功率
}

public struct USBDeviceReading: Sendable, Equatable, Identifiable {
    public var id: UInt64              // IORegistry entry ID
    public var name: String
    public var allocationMA: Int
    public var isBuiltIn: Bool
}

public struct RawReadings: Sendable, Equatable {
    public var smc: SMCPowerReadings?
    public var battery: BatteryReadings?
    public var ports: [PortReading]
    public var usbDevices: [USBDeviceReading]
}

public enum Quality: Sendable, Equatable {
    case measured, contracted, allocated, derived, unavailable
}

public struct Metric: Sendable, Equatable {
    public var watts: Double?
    public var quality: Quality
}

public enum PowerState: Sendable, Equatable {
    case charging, pluggedIdle, pluggedDraining, onBattery, unsupported
}

public struct ExternalDevice: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var watts: Double
    public var quality: Quality
}

public struct PowerSnapshot: Sendable, Equatable {
    public var state: PowerState
    public var total: Metric
    public var input: Metric
    public var adapterLoss: Metric
    public var charge: Metric
    public var discharge: Metric
    public var display: Metric
    public var external: Metric
    public var computer: Metric
    public var externalDevices: [ExternalDevice]
    public var batteryPercent: Int?
    public var timeToEmptyMin: Int?
    public var adapterWatts: Int?
}
```

### 7.3 Core 函数

```swift
public enum FourCC {
    static func code(_ s: String) -> UInt32
    static func string(_ code: UInt32) -> String
}

public enum SMCDecoder {
    static func decode(type: String, bytes: [UInt8]) -> Double?
}

public enum BatteryParser {
    static func parse(_ props: [String: Any]) -> BatteryReadings?
}

public enum PortParser {
    static func parse(_ props: [String: Any]) -> PortReading?
}

public enum USBDeviceParser {
    static func parse(_ props: [String: Any], entryID: UInt64) -> USBDeviceReading?
}

public protocol ExternalPowerStrategy: Sendable {
    func evaluate(ports: [PortReading], devices: [USBDeviceReading]) -> (Metric, [ExternalDevice])
}
public struct LayeredExternalPowerStrategy: ExternalPowerStrategy { /* 实现 4.4 */ }

public enum PowerDeriver {
    static func derive(
        _ raw: RawReadings,
        external: any ExternalPowerStrategy = LayeredExternalPowerStrategy()
    ) -> PowerSnapshot
}

public enum PowerFormatter {
    static func text(_ metric: Metric) -> String     // "≈ 3.3 W" / "—"
    static func tag(_ quality: Quality) -> String?   // "协商" / "分配" / nil
}

public struct Smoother {
    init(alpha: Double = 0.35)
    mutating func push(_ value: Double?) -> Double?
    mutating func reset()
}

public enum IconState {
    case charging, plugged, battery, unavailable
    init(_ state: PowerState)
}

public enum Activity { case panelOpen, ambient, idle, suspended }

public enum SamplingPolicy {
    static func interval(for activity: Activity, panelInterval: Duration) -> Duration?
}
```

解析与解码细节：

- `SMCDecoder` 支持以下类型；未知类型返回 nil：
  - `flt `：Float32，小端（Apple Silicon）
  - `ui8 `、`ui16`、`ui32`：大端无符号整数
  - `si16`：大端有符号整数
  - `sp78`：大端有符号 8.8 定点数，计算方式为 `Int16 / 256`
  - `fpe2`：大端无符号定点数，计算方式为 `UInt16 / 4`
- 有符号电流使用 `NSNumber.int64Value` 读取：
  - 如果结果大于 `Int64(Int32.max)`，使用 `Int(Int32(truncatingIfNeeded:))`。
  - 这是为了兼容 `ioreg` 中显示为 `18446744073...` 的负数。
- `RegistryValue` 提供 `int(_:)`、`bool(_:)`、`string(_:)` 和 `dict(_:)`：
  - `Bool` 同时接受 `Bool` 和 `NSNumber`。
  - `string` 同时接受 `String` 和 `Data`；`Data` 按 UTF-8 解码，并去掉末尾的 `\0`。

### 7.4 System 层

```swift
public final class SMCClient {
    public init?()
    public func readDouble(_ key: String) -> Double?
    public func allKeys() -> [String]   // 只给 probe 使用
    public func close()
}

public final class SystemPowerReader {
    public init()
    public func read() -> RawReadings
}
```

说明：

- 如果 `SMCClient.init?` 打开 `AppleSMC` 失败，返回 nil。
- `SystemPowerReader.read()` 不能抛错；读取失败的字段一律为 nil。

---

## 8. UI 设计规范

### 8.1 菜单栏图标

| `IconState` | SF Symbol |
|---|---|
| `.charging` | `bolt.fill` |
| `.plugged`（`pluggedIdle` / `pluggedDraining`） | `bolt` |
| `.battery` | `bolt.slash` |
| `.unavailable` | `bolt.trianglebadge.exclamationmark` |

- 图标设置 `image.isTemplate = true`，尺寸为 15 pt，使用 regular 字重。
- 开启“菜单栏显示数值”后，按钮标题显示 `totalW` 的整数，例如 ` 34W`。
  - 字体：`NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)`
- 左键打开或关闭面板；右键或 Control + 左键打开设置菜单。

### 8.2 面板布局（宽度和高度都随内容自适应）

```text
┌──────────────────────────────────────────────────────────────┐
│ ╭───────────────╮  ╭──────────────────────────────────────╮  │
│ │ 充电功率       │  │ 整机功耗                     33.0 W  │  │
│ │   ╭──────╮    │  │ ▰▰▰▰▰|▰▰▰▰▰▰▰▰▰▰▰▰▰|▰▰  占比条        │  │
│ │  │ 28.4 W │   │  │ [■] 屏幕              8.3 W    25%   │  │
│ │  │ ▭ 54%  │   │  │ [■] 电脑             21.5 W    65%   │  │
│ │   ╰──────╯    │  │ [■] 外接设备 [分配]  ≈ 3.3 W    10%   │  │
│ │ (● 正在充电)   │  │      • USB 10_100_1000 LAN  ≈ 1.8 W  │  │
│ │  90W 适配器    │  │      • EarPods              ≈ 1.5 W  │  │
│ ╰───────────────╯  ╰──────────────────────────────────────╯  │
│ 适配器输入 29.4 W  ·  转换损耗 0.6 W                          │
└──────────────────────────────────────────────────────────────┘
```

**自适应规则**

- 宽度：`Theme.panelWidth(for:)`，最小 440 pt，最大 620 pt。
  - 按最长的外接设备名称（11 pt 系统字体）计算需要的宽度；名称宽度超过 84 pt 的部分会加到面板宽度上。
  - 超过 620 pt 时，设备名称从中间截断（`truncationMode(.middle)`）。
- 高度：外接设备**全部平铺列出，不做折叠或展开**。设备越多，面板越高。
  - 由 `NSHostingController.sizingOptions = .preferredContentSize` 驱动；`PanelController` 通过 KVO 监听 `preferredContentSize`，按 `fittingSize` 调整窗口大小，并保持顶部贴着菜单栏。
- **右侧卡片决定面板高度**：最小 176 pt，按设备数量向下增长。左侧卡片通过 `.overlay(alignment: .leading)` 叠在右侧卡片的左边距里，高度始终和右侧一致。设备少时不会留白。
- 左侧圆环直径 = `min(122, 可用宽度, 可用高度)`，用 `GeometryReader` 计算；数字、单位、电量字号和线宽都按直径等比缩放（0.27 / 0.115 / 0.086 / 0.066）。

**左侧：充电卡片（宽 150 pt）**

- 卡片背景按状态着色：
  - 充电中：绿色到薄荷色的淡渐变
  - 放电或电池补电：橙色淡渐变
  - 其他状态：中性灰
- 标题：`充电功率` 或 `放电功率`，12 pt，`.secondary`，左对齐。
- 270° 圆弧：直径自适应，最大 122 pt；圆头；底下有浅色轨道。
  - 进度为 `主数字 / adapterWatts`；没有适配器功率时，用 100 W 作为分母。
- 圆弧内是主数字：字号为直径 × 0.27，`.rounded`、semibold、等宽数字；后面跟 `W`，字号为直径 × 0.115。主数字下方显示电池图标和电量百分比，电池图标随电量变化。
- 状态胶囊：彩色圆点 + 文案。

| 状态 | 主数字 | 胶囊文案 | 圆点和圆弧 |
|---|---|---|---|
| `charging` | `chargeW` | `正在充电` | 绿色；圆弧为薄荷色到绿色渐变 |
| `pluggedIdle` | `0` | 电量 ≥ 100% 时显示 `已充满`，否则显示 `暂停充电`（例如开了优化充电或充电上限） | 灰色 |
| `pluggedDraining` | `dischargeW` | `电池补电` | 橙色；圆弧为黄色到橙色渐变 |
| `onBattery` | `dischargeW` | `剩余 h:mm`（剩余时间未知时显示 `使用电池`） | 橙色 |
| `unsupported` | `—` | `此 Mac 不支持` | 灰色 |

- 接电源时，适配器功率合并进胶囊，例如 `正在充电 · 90W`；不再单独占一行。

**右侧：功耗卡片**

1. 头部：左侧是 `整机功耗`（12 pt，`.secondary`），右侧是整机功率（15 pt，`.rounded`、semibold）。
2. 占比条：6 pt 高的胶囊，分为屏幕、电脑、外接设备三段，颜色分别为 cyan、indigo、orange。段与段之间留 2 pt 间隔，每段最少 3 pt 宽。
3. 三行，顺序固定：

| 行 | 图标 | 颜色 |
|---|---|---|
| 屏幕 | `display` | cyan |
| 电脑 | `laptopcomputer` | indigo |
| 外接设备 | `cable.connector` | orange |

- 每行从左到右依次是：
  - `IconTile`：22 pt 圆角方块，填充颜色渐变，内部是白色 SF Symbol
  - 名称：13 pt，medium
  - 质量标签胶囊（`分配` / `协商`）
  - 弹性空白
  - 数值：13 pt，`.rounded`、semibold；估算值使用 `.secondary`
  - 占比：10.5 pt，`.tertiary`，宽 30 pt，右对齐
4. 外接设备行下方是 `ExternalDeviceList`，列出每台设备：
   - 左侧缩进 30 pt，和名称对齐
   - 每台设备一行：小圆点 + 名称（11 pt）+ `≈ x.x W`
   - 设备数值和上方各行的数值右对齐（右侧留 38 pt）
   - 只有当设备的质量和上级行不同时，才显示该设备的标签
   - 没有设备时显示 `无外接取电设备`，使用 `.tertiary`

**底部栏**

- 字号 10.5 pt，`.secondary`。
- 接电源时显示：`适配器输入 x W  ·  转换损耗 x W`。
- 使用电池时显示：`电池供电`。
- 缺失的字段直接省略。

### 8.3 视觉与动效

- 卡片：圆角 16 pt（`.continuous`），填充 `primary.opacity(0.045)`，并加 0.5 pt 的 `primary.opacity(0.08)` 描边。卡片样式统一用 `.card()` 修饰符。
- **面板容器按外观区分**（`PanelController`）：
  - **深色**：系统 `NSPopover`（`.transient`，带箭头，macOS 27 的 Liquid Glass 半透明背景）。卡片填充 `primary.opacity(0.045)`，加 `primary.opacity(0.08)` 描边；状态色调（绿或橙渐变，0.20/0.05、0.18/0.04）**替换**底色。这是用户认可的样式，不要改动。
  - **浅色**：无边框 `NSPanel` + `PanelChrome`。系统 popover 的玻璃外框会透出背后的深色桌面，浅色下发灰发蓝，而且无法修改，所以浅色不用 popover。背景纯白，圆角 22 pt，0.5 pt 描边，加窗口阴影，没有箭头；定位在菜单栏图标正下方。点击外部、切换到其他应用、再次点击图标都会关闭。卡片底色为 `Color(white: 0.965)` + 黑色 5% 描边，状态色调（0.16/0.04、0.16/0.03）**叠加**在底色之上。
  - 打开时根据 `NSApp.effectiveAppearance` 决定用哪种容器，并把该外观设置到容器上，保证运行中切换外观后下次打开即生效。
- 面板内边距 14 pt，卡片间距 10 pt，卡片内边距 14 pt。
- 数字切换使用 `.contentTransition(.numericText())`，动画为 `.easeOut(duration: 0.25)`。
- 圆弧和占比条使用 `.spring(response: 0.35, dampingFraction: 0.85)`。
- 系统开启“减少动态效果”时（`accessibilityReduceMotion`），关闭所有动画。所有动画都通过 `Theme.animation(_:)` 和 `Theme.spring(_:)` 获取。
- 每行都要设置 `accessibilityLabel`，例如 `屏幕功率 8.3 瓦，实测`。
- 视觉检查：运行 `WattBar --render-panel out.png <charging|full|battery|many|none>[-dark]`，把面板离屏渲染成 PNG。

### 8.4 设置菜单（右键）

- 刷新频率：1 秒 / 2 秒 / 5 秒，单选
- 在菜单栏显示功率，勾选项
- 外观：跟随系统（默认）/ 浅色 / 深色，单选。保存在 `wattbar.appearance`；通过设置 `NSApp.appearance` 生效（`nil` / `.aqua` / `.darkAqua`），同时作用于菜单。启动时和设置变化时都要应用。
  - 面板显示前设置 `panel.appearance = NSApp.effectiveAppearance`，保证运行中切换外观后立即生效。
- 登录时启动：使用 `SMAppService.mainApp`；只有 `.app` 包内运行时才启用
- 退出 WattBar

设置统一保存在 `UserDefaults`，键名使用 `wattbar.` 前缀。

---

## 9. 性能预算与手段

### 9.1 性能预算

| 指标 | 面板关闭（idle） | 面板打开（1 s） |
|---|---|---|
| CPU 平均占用 | ≈ 0% | < 1% |
| 内存 `footprint` | ≤ 25 MB | ≤ 45 MB |
| 单次 `read()` 耗时 | — | < 2 ms（用 probe 的 `--bench` 测） |
| 周期唤醒 | 无 | 每次采样 1 次 |

### 9.2 手段

- 面板关闭且菜单栏不显示数值时，App 不轮询。
- 面板关闭后释放 SwiftUI 树。
- SMC 连接和 `KeyInfo` 都做缓存。
- USB 设备列表由事件驱动更新。
- `Clock.sleep` 设置 10% tolerance，让系统可以合并唤醒。
- 显示值变化小于 0.05 W 时，不写入 `@Observable` 属性，避免无意义的重绘。
- 资源只使用 SF Symbols，不打包图片。

### 9.3 测量命令

```bash
footprint WattBar
top -l 60 -s 1 -pid "$(pgrep -x WattBar)" -stats cpu,mem
swift run -c release wattbar-probe --bench 1000
```

如果 SwiftUI 面板的内存超过预算，改用 AppKit 自绘面板，布局保持不变。

---

## 10. 测试方案

### 10.1 框架与原则

- 使用 Swift Testing：`import Testing`、`@Test`、`#expect`。
- 运行命令：`swift test`。
- 只对 `WattBarCore` 写单元测试。`WattBarSystem` 和 UI 通过 probe 工具和手工检查验证。
- 浮点比较使用 `abs(a - b) < 0.001`。
- fixture 用脚本采集真实机器数据，不要手写 IORegistry 结构。

### 10.2 Fixture 采集（必须在 Codex 沙箱外运行）

`scripts/capture-fixtures.sh <name>` 先导出原始 `ioreg` 数据，再用 `scripts/sanitize-fixture.swift` 按白名单过滤，只保留解析器读取的字段（去掉序列号、UUID、进程名等隐私信息），最后生成以下文件。**禁止提交未过滤的 ioreg 原始导出。**

```text
Tests/WattBarCoreTests/Fixtures/battery_<name>.plist   # 来源：ioreg -a -r -c AppleSmartBattery
Tests/WattBarCoreTests/Fixtures/usb_<name>.plist       # 来源：ioreg -a -r -c IOUSBHostDevice
Tests/WattBarCoreTests/Fixtures/ports_<name>.plist     # 来源：ioreg -a -r -c AppleTCControllerType10
```

至少采集这三种状态：

- `ac_full`：接电源，已充满
- `ac_charging`：接电源，正在充电
- `battery`：拔掉电源

`FixtureLoader` 使用 `PropertyListSerialization` 解析成 `[[String: Any]]`，并取第一项或遍历所有项。

### 10.3 单元测试清单（最少要实现这些）

| 文件 | 用例 |
|---|---|
| `FourCCTests` | `"PSTR"` 转换后再转回来仍为 `"PSTR"`；`"flt "` 中的空格要保留 |
| `SMCDecoderTests` | `flt ` 的 `[0x00,0x00,0x05,0x41]` → 8.3125；`ui16` 的 `[0x01,0x00]` → 256；`sp78` 的 `[0x1E,0x80]` → 30.5；`fpe2` 的 `[0x00,0x0A]` → 2.5；未知类型 → nil；字节不足 → nil |
| `BatteryParserTests` | `ac_full`：`externalConnected = true`，`fullyCharged = true`，`amperage = 0`，`adapterWatts = 90`，`telemetry.systemLoadMW > 0`；`battery`：`amperage < 0`；`InstantAmperage = 18446744073709550616` → -1000；`AvgTimeToEmpty = 65535` → nil；空字典 → nil |
| `USBDeviceParserTests` | `UsbPowerSinkAllocation = 350` → 350 mA；有 `"Built-In" = true` 时 `isBuiltIn = true`；名称优先取 `USB Product Name`，其次取 `kUSBProductString`，最后显示 `"未知设备"` |
| `PortParserTests` | 能正确解析 `PortNumber`、`ConnectionActive` 和 `TransportsActive`；`PowerOutDetails` 中 `PDPowermW = 15000` → 15.0；只有 `Voltage = 9000` 和 `Current = 2000` 时 → 18.0；没有 `PowerOutDetails` 时 → nil |
| `ExternalPowerStrategyTests` | 有协商功率时只累加协商值，质量为 `contracted`；只有分配额度时，350 mA + 300 mA → 3.25 W，质量为 `allocated`；内建设备被排除；完全没有设备时 → 0 W，质量为 `measured`；`allocation = 0` 的设备被排除 |
| `PowerDeriverTests` | 见 10.4 |
| `PowerStateTests` | 覆盖 4.5 中的 5 种状态，以及 `battery == nil` 的情况 |
| `PowerFormatterTests` | 0.04 → `"0 W"`；12.345 → `"12.3 W"`；112.4 → `"112 W"`；`allocated` 3.25 → `"≈ 3.3 W"`，标签为 `"分配"`；`unavailable` → `"—"` |
| `SmootherTests` | 第一个值原样返回；`alpha = 0.35` 时，先输入 10 再输入 20 → 13.5；输入 nil 时返回上一个值；`reset` 后重新按第一个值处理 |
| `SamplingPolicyTests` | `panelOpen + 2s` → 2 s；`ambient` → 5 s；`idle` → nil；`suspended` → nil |

### 10.4 `PowerDeriverTests` 必测场景

在测试中直接构造 `RawReadings`：

| 场景 | 输入要点 | 期望 |
|---|---|---|
| SMC 完整 | `PSTR = 33`，`PDTR = 29.4`，`PDBR = 8.3`，USB 分配为 650 mA | `display = 8.3`（measured）；`external = 3.25`（allocated）；`computer = 21.45`（derived） |
| SMC 缺失 | `smc = nil`，`SystemLoad = 26860` | `total = 26.86`，`display` 为 unavailable，`computer = 26.86 − external` |
| 正在充电 | `V = 12600`，`I = 2000` | `charge = 25.2`，`discharge = 0`，状态为 `.charging` |
| 使用电池 | 未接电源，`I = -1500`，`V = 12000`，`smc = nil`，无 telemetry | `total = 18.0`，`input = 0`，`discharge = 18.0` |
| 外接值超过总功率 | `total = 5`，`display = 3`，`external = 4` | `computer = 0`，不能为负 |
| 非法值 | `PSTR = NaN` 或 `PSTR = 9999` | 回退到 `SystemLoad` |
| 不支持的机器 | `battery = nil`，`smc = nil` | 状态为 `.unsupported`，`total` 为 unavailable |

### 10.5 手工验证（每次改动数据层后都要做）

1. 在沙箱外运行 `swift run wattbar-probe --once`，同时运行：

   ```bash
   ioreg -rw0 -c AppleSmartBattery | rg 'Voltage|InstantAmperage|SystemLoad'
   ```

   确认 V/I 值完全一致。
2. 运行 `wattbar-probe` 30 秒，确认 `PSTR` 平均值与 `SystemLoad` 平均值的差距在 15% 以内。如果超过，记录到第 13 节，不要擅自修改优先级。
3. 调整屏幕亮度，从最低调到最高，确认 `PDBR` 明显上升。
4. 插上和拔掉 USB 设备后，外接设备列表能在 1 秒内更新。
5. 拔掉和插上电源后，菜单栏图标能在 1 秒内切换。

### 10.6 `wattbar-probe` 用法

```text
wattbar-probe               # 每秒打印 RawReadings 和 PowerSnapshot（人类可读）
wattbar-probe --once        # 打印一次后退出
wattbar-probe --json        # 以 JSON 格式输出 PowerSnapshot
wattbar-probe --smc-dump P  # 列出所有以 P 开头、值不为 0 的 flt 键，用于发现新键
wattbar-probe --bench 1000  # 调用 read() 1000 次，打印平均耗时和 p99 耗时
```

---

## 11. 实现步骤（严格按顺序，每步都有完成标准）

| # | 内容 | 完成标准 |
|---|---|---|
| 1 | 创建 `Package.swift`、空 target 和一个占位测试 | `swift build && swift test` 通过 |
| 2 | `FourCC`、`SMCDecoder`、`RegistryValue` 和对应测试 | 对应测试全部通过 |
| 3 | 运行 `capture-fixtures.sh ac_full`；实现三个 Parser 和测试 | Parser 测试通过 |
| 4 | 实现 Core 模型、`LayeredExternalPowerStrategy`、`PowerDeriver`、`PowerState` 和测试 | 10.4 中的场景全部通过 |
| 5 | 实现 `PowerFormatter`、`Smoother`、`IconState`、`SamplingPolicy` 和测试 | 全部测试通过 |
| 6 | 实现 `CSMC`、`SMCClient`、`RegistryReader`、`SystemPowerReader`、`USBDeviceCache`，以及 `wattbar-probe` | 10.5 的第 1–3 项通过；`--bench` 平均耗时 < 2 ms |
| 7 | 实现 `AppDelegate`、`StatusItemController`、`PowerSampler`、`PowerStore` 和 `PowerSourceObserver` | 菜单栏出现图标，插拔电源后图标会切换 |
| 8 | 实现 `PanelController` 和 UI 全部视图 | 面板与第 8 节一致；浅色和深色模式下都正常 |
| 9 | 实现 `SettingsMenu`、`Settings` 和登录启动 | 设置项生效，重启 App 后仍然保留 |
| 10 | 实现 `scripts/bundle.sh` 并测量性能 | `WattBar.app` 能运行，第 9 节的预算全部达标 |

---

## 12. 构建与运行

```bash
swift build
swift test
swift run wattbar-probe --once      # 需要在 Codex 沙箱外运行，否则 SMC 读取会被拒绝
./scripts/bundle.sh                 # 生成 build/WattBar.app
open build/WattBar.app
```

`bundle.sh` 需要完成以下工作：

1. 运行 `swift build -c release --product WattBar`。
2. 创建 `build/WattBar.app/Contents/{MacOS,Resources}`，并复制可执行文件。
3. 写入 `Info.plist`：
   - `CFBundleIdentifier`：默认 `io.github.wattbar.WattBar`，可以用环境变量 `WATTBAR_BUNDLE_ID` 覆盖
   - `CFBundleExecutable = WattBar`
   - `LSUIElement = true`
   - `LSMinimumSystemVersion = 14.0`
   - `CFBundleShortVersionString = 0.1.0`
4. 运行 `codesign --force --sign - build/WattBar.app`。

不启用 App Sandbox。开发机已确认，SMC 读取只在沙箱外运行时才能成功。

---

## 13. 已知限制与待验证项

| 项 | 现状 | 验证方法 |
|---|---|---|
| `PSTR` 与 `SystemLoad` 的差异 | **已查证**：两者都表示整机实际耗电，都不含给电池充电的功率；`PSTR` 约 1 s 更新一次，`SystemLoad` 约 20 s 更新一次。所以继续以 `PSTR` 为主，以 `SystemLoad` 为回退 | 无需再验证 |
| `PPBR` 的符号含义 | 已充满时为 1.29 W，含义不明 | 分别在充电和放电时观察；确认前不在 UI 中使用 |
| `PowerOutDetails` 的位置和键名 | 开发机当前没有出现 | 接入 PD 供电设备（例如给手机充电），再用 `ioreg -l` 搜索 |
| 端口级实测功率 | 开发机发现 `D2JV = 5.27`，可能是端口 VBUS 电压 | 用 `--smc-dump D` 和 `--smc-dump I` 对比插拔前后；有结论后新增 `measured` 外接层 |
| 外接设备功率精度 | 协商值和分配值都只是上限 | UI 中已标注；这是行业通行做法 |
| Mini-LED 背光 | `PDBR` 是实测值，会随画面内容变化 | 无需处理 |

---

## 14. 实现状态（2026-11-27）

第 11 节的 10 个步骤已全部完成。

| 项 | 结果 |
|---|---|
| 单元测试 | 60 个测试、11 个套件全部通过；Swift 6 严格并发零警告 |
| fixture | 只采集了 `ac_full`；`ac_charging` 和 `battery` 状态用内联字典测试，待插拔电源后补采 |
| `read()` 耗时 | release 版平均 1.24 ms（预算 < 2 ms） |
| 内存和 CPU | 面板关闭时 `footprint` 16 MB，CPU ≈ 0%（预算 ≤ 25 MB） |
| 面板打开时的内存和 CPU | 未测：沙箱外的自动化点击不可用，需要手动点开面板后运行 `footprint WattBar` |

### 14.1 相对前文的偏离

1. 面板改为卡片式布局，宽度在 440–620 pt 之间自适应；外接设备不再折叠，全部平铺显示（见 8.2）。
2. 新增 `scripts/swiftw.sh`：封装 `swift build/test/run`，把缓存重定向到 `/tmp/wattbar-cache`。**在 Codex 沙箱内必须用它代替裸 `swift` 命令**，否则会因写入 `~/.cache` 被拒而失败。
3. `scripts/bundle.sh` 使用 `-debug-info-format none`：沙箱内 `dsymutil` 会失败，个人使用也不需要 dSYM。
4. `SystemPowerReader` 对端口按 `PortNumber` 去重（优先保留 `ConnectionActive == true` 的条目），因为 `AppleTCControllerType10/11` 在这台机器上会返回重复端口号。
5. 新增 `WattBar --render-panel <out.png> [charging|full|battery][-dark]`：把面板离屏渲染成 PNG，用于不打开 GUI 时检查布局。实现在 `Sources/WattBar/PanelRenderer.swift`。

### 14.2 常用命令

```bash
scripts/swiftw.sh test                              # 单元测试
scripts/capture-fixtures.sh <name>                  # 采集 fixture（沙箱外）
.build/out/Products/Debug/wattbar-probe --once      # 打印原始读数（沙箱外）
scripts/bundle.sh && open build/WattBar.app         # 打包并启动
```

### 14.3 待办

- 插拔电源，补采 `ac_charging` 和 `battery` fixture，并把对应测试改成读 fixture。
- 手动点开面板，测面板打开时的 `footprint` 和 CPU。
- 给 USB-C 设备供电（例如给手机充电），确认 `PowerOutDetails` 的位置和键名（第 13 节）。
