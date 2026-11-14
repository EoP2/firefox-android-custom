# ironfox/ —— 叠加到 IronFox 上的补丁和脚本

配合 `.github/workflows/ironfox-build.yml` 使用。补丁是针对 **IronFox v160.0（Firefox 160.0）** 写的，打在 IronFox 自己的补丁**之后**。它们是 `firefox-android-custom` 那套补丁里挑出来、并按 IronFox 的源码改写过的一部分；之前的补丁整套作废，已被替换。

## 目录

| 路径 | 作用 |
|---|---|
| `patches/` | 要叠加到 IronFox 上的补丁，按文件名字节序依次应用 |
| `apply-custom-patches.sh` | 把 `patches/` 里的补丁打在「IronFox 已经打完自己补丁」的 Gecko 源码上：`--fuzz=0`，先 dry-run，任何一个失败就中止 |
| `prebuild-rest.sh` | 跑 IronFox `prebuild.sh all` 里除 `firefox` 以外的其余目标；带一个检查：IronFox 改了 `all` 的组成就报错，而不是悄悄漏跑 |
| `check-aar-channel.sh` | 判断 GeckoView 压缩包是 Release 还是 Nightly 渠道编的 |
| `skip-sign.sh` | 空操作版的签名脚本：不勾选 `sign` 时，工作流用它替换 IronFox 的 `scripts/sign.sh`，保留真正未签名的 APK |
| `watchdog.sh` | 包在长时间运行的命令外面：定期打印磁盘和负载，卡住时抓取诊断信息并终止，不再白等到 6 小时上限 |

## 补丁清单

**已包含（7 个）。** 每个补丁做什么、为什么这样做，见 Firefox 那份 README 里的同名小节；这里只写和 IronFox 有关的部分。

| 补丁 | 内容 | 与 Firefox 版的差异 |
|---|---|---|
| `0001-address-bar` | 地址栏改回旧版样式：40dp 高、4dp 圆角、盾牌图标间距收窄、搜索引擎按钮去掉下拉箭头 | 无 |
| `0002-context-menu` | 网页长按菜单：去掉「分享链接」「分享图片」、小圆角、标题边距收窄 | 无（原补丁里有一个上下文前 5 行后 3 行、不对称的 hunk，只能靠 fuzz 2 套上，重新生成后消除） |
| `0005-main-menu-content` | 主菜单的内容、布局和样式 | 见下 |
| `0006-main-menu-panel` | 主菜单面板：宽 200dp 靠右、不遮罩、无抓手、8dp 圆角 | 无 |
| `0007-tab-manager-sheet` | 标签页管理改回底部弹层 | 无 |
| `0008-tab-list-classic-style` | 标签列表改回旧版平铺样式 | 无 |
| `compact-main-menu` | 主菜单行高压缩到 44dp / 48dp | 无 |

表里的「无」指增删的代码行与 Firefox 版逐文件相同，只是上下文按 IronFox 打完补丁后的源码重新生成。

**`0005` 与 Firefox 版的差异：**

- **账户入口：无条件去掉**，登录与否都不显示。IronFox 原本在启用账户功能并已登录时才显示它；这里连同 IronFox 加的 `if (isFxaSignedIn)` 包装一起删掉。`MainMenu` 的 `isFxaSignedIn` 参数保留但不再使用（该函数已有 `@Suppress("UNUSED_PARAMETER")`）。
- **密码入口：** 主菜单资料库里的 `showPasswords` 写死为 `false`，不管 IronFox 的「保存登录信息」设置是否开启都不显示。
- **去掉两处，因为 IronFox 已处理：** 「设为默认浏览器」横幅（IronFox 每次启动都把 `show_menu_banner` 置为 `false`）；「反馈网站问题」（IronFox 已把调用注释掉）。
- **其余照旧：** 分享、定制主页、扩展项小字、桌面版网站徽标的去除，书签 / 历史 / 下载并入导航栏，设置移到扩展上方，导航栏两排，无块状背景，区块间距收窄。IronFox 没有处理这些（在它的补丁、脚本和 overlay 里都搜不到）。

**没有包含：**

| 补丁 | 原因 |
|---|---|
| `0003-remove-vpn-ui` | 按要求不做。IronFox 有「Enable Firefox VPN」开关，**默认是开**，只有登录 Mozilla 账户后 VPN 入口才会出现（主菜单、站点信息面板）；不想看到就在 IronFox 设置里手动关掉 |
| `0004-extensions-hide-recommended` | IronFox 已经去除：`a-c-disable-amo-collections.patch` 把 `AddonManager.getAddons()` 里获取推荐扩展的代码注释掉了，返回的只剩已安装和内置的扩展；扩展页的「推荐」分区和主菜单里的推荐扩展都只取「未安装」的，所以永远是空的 |
| `0009-tab-manager-banner` | 按要求暂不移植。IronFox 让页签页按条件动态显示（同步页看是否登录账户，普通页看「始终隐私浏览」），要做的话得按它的逻辑重写（`Page.kt`、`TabsTrayBanner.kt`、`TabsTray.kt`） |
| `coexist-custom-package` | 按要求暂不移植。IronFox 构建时按渠道设置包名：Release 是 `org.ironfoxoss.ironfox`，Nightly 是 `org.ironfoxoss.ironfox.nightly` |

## 补丁放在构建流程的哪一步

IronFox 的构建分三段：`get_sources.sh`（下载源码和工具链）→ `prebuild.sh`（**改源码**）→ `build.sh`（编译）。补丁属于「改源码」，要落在 prebuild 里。

`prebuild.sh` 里先后做这些事：先把 IronFox 自己的补丁打到 Firefox 源码上（`firefox` 目标），再准备 Android Components、Application Services、Fenix、Glean 等子项目。其中 `prepare_fenix` 会把 `app/src/main/res/` 和 `app/build.gradle` 备份到临时目录，而 `build.sh` 开头又把这两样**删掉，再用备份还原**。

这带来两个限制：

1. **不能登记进 IronFox 的补丁清单**（之前的做法）。IronFox 在应用任何补丁之前，先拿每个补丁在**原版**源码上试一遍，任何一个套不上就整体中止。`0005` 要删掉的账户入口，IronFox 已经改成了 `if (isFxaSignedIn) { … }`，`0005` 删的是改过的版本，套不上原版。（其余 6 个补丁在原版上也能套。）
2. **不能等 prebuild 全部跑完再打。** `0001`、`0006`、`0007` 改了 `res/` 下的文件（`dimens.xml`、`nav_graph.xml`、新增的 drawable），晚打会被备份冲掉。

所以把 prebuild 拆成三步，补丁夹在中间：

1. `prebuild.sh firefox`：IronFox 检查并应用它自己的补丁；
2. `apply-custom-patches.sh`：你的补丁打在上面；
3. `prebuild-rest.sh`：其余目标，包括备份 `res/`。

`prebuild.sh` 本来就支持按目标单独运行（`ac`、`fenix`、`firefox` 等），没有改 IronFox 的任何脚本。代价是 IronFox 以后如果改了 `all` 的组成，`prebuild-rest.sh` 里的目标清单要同步；脚本里有检查，不一致会直接报错而不是漏跑。

## 增加或替换补丁时的规则

1. 补丁是针对「IronFox 打完补丁之后」的源码写的，**不要求能套在原版上**；顺序就是文件名的字节序（`LC_ALL=C`）。
2. 路径相对 Gecko 源码根目录（`mobile/android/…`），按 `-p1` 应用，且 `--fuzz=0`：上下文必须完全对得上，只允许行号偏移。用 `git diff` 导出的补丁（对称的 3 行上下文）满足这一点；手工裁剪过上下文的补丁会失败。
3. 补丁之间应当彼此独立：拿掉任意一个，其余仍能依次应用（现有 7 个已验证）。
4. 要避开 `prepare_*` 在补丁之后用 `sed` 改的行。例如 `prepare_fenix` 会注释掉 `TabManagementFragment.kt` 里的 `TabsTrayTelemetryMiddleware`，还有一条替换 `googleg_standard_color_18` 的 `sed`（160.0 里没有这个字符串，是空操作）。
5. 脚本要用 `--forward`，不要换成 `--batch`：`--batch` 遇到已应用的补丁会自动假设 `-R`，把它悄悄撤销掉，而且退出码是 0。

**这 7 个补丁是怎么生成的**（升级 IronFox 后重做时用得上）：

1. 取与 IronFox 同一提交的 Gecko 源码（它的 `get_sources` 用的那个；Firefox 160.0 是 `2887d9de…`），只需要 `mobile/android`；
2. 按 `scripts/patches.yaml` 的顺序，用 `patch -p1 --no-backup-if-mismatch` 套上 IronFox 的补丁（只取路径在 `mobile/android` 下的部分），得到「IronFox 打完补丁后」的源码；
3. 对它建一个 git 基线，修改文件，`git diff` 导出补丁；
4. 用 `apply-custom-patches.sh` 同样的参数验证：单独、依次、拿掉任意一个，都能套上。

## 本机快速判断 AAR 渠道（不用等 Actions）

```bash
curl -fLO https://artifacts.ironfoxoss.org/ironfox/<流水线ID>/geckoview-arm64-v8a.zip
bash ironfox/check-aar-channel.sh geckoview-arm64-v8a.zip     # 输出 release / nightly / unknown
```

输出 `unknown` 表示没能检测出来（这个检测是按源码推断写的，没有在真实 AAR 上验证过），不代表是哪个渠道。

## 在 Ubuntu 上用本地模式跑 IronFox 遇到的问题（工作流里都已处理）

IronFox 官方 CI 用 Fedora，并且开着它的 CI 模式；文档说 Ubuntu 可以原生构建，但实际有这些坑：

| 现象 | 原因 | 处理 |
|---|---|---|
| `bootstrap.sh` 在 CI 里停住 | Ubuntu 分支的 `apt upgrade` 没带 `-y` | 工作流自己装依赖 |
| 读不到补丁清单 | apt 版 `yq` 是 Python 版，输出带引号 | 下载 mikefarah 版 `yq`，用 `IRONFOX_YQ` 指给它 |
| `build.sh` 开头报缺 `IRONFOX_SB_GAPI_KEY_FILE`，随后 `Aborting...` | 检查要求文件存在，否则本地模式弹出确认提示，Actions 里没有终端可输入 | 放占位文件（bundle 构建里 Gecko 不编译，文件内容不会被读取） |
| `mozconfig_loader: 4: set: Illegal option -o pipefail`，随后 mach 永远挂住 | IronFox 的 mozconfig 是 bash 写法，mach 用 PATH 里的 `sh` 执行它；Ubuntu 的 `sh` 是 dash | 设置 `IRONFOX_SH=/bin/bash`，并在 get_sources 之后自检 |
| 没有 `/usr/bin/clang` | 只装了 `clang-18` | 多装 `clang`（实测缺它时 `env.sh` 不报错，装上更保险） |
| 不签名时产物是 `-debug-signed`，用的是一次性的 debug 密钥 | `IRONFOX_SIGN=0` 时不给 Gradle 加 `-PdisableDebugSigning`；`IRONFOX_SIGN` 由 4 个 keystore 变量推导 | 设占位 keystore 变量走 `IRONFOX_SIGN=1`，并用 `skip-sign.sh` 替换 `sign.sh`（见上一节） |

mach 159 在 mozconfig 加载失败后会挂住的原因：它退出前要等一个“遥测初始化完成”的信号，这个信号在后台回调里设置；回调里会再加载一次 mozconfig，同样失败，抛出的异常没被捕获，信号就永远设不上。这是 mach 在这条出错路径上的行为，没有环境变量能关掉它，所以才加了 `watchdog.sh` 兜底。

## 产物与签名

默认（不勾选 `sign`）产出**真正未签名**的 APK，需要你在本地用自己的 keystore 签名后才能安装。产物在 `IronFox/outputs/` 下：

| 文件 | 大小（取自上一次实际构建，未签名版应当相近） |
|---|---|
| `unsigned/ironfox-<版本>-arm64-v8a-unsigned.apk` | 约 166 MB |
| `unsigned/ironfox-<版本>-armeabi-v7a-unsigned.apk` | 约 163 MB |
| `unsigned/ironfox-<版本>-x86_64-unsigned.apk` | 约 173 MB |
| `unsigned/ironfox-<版本>-universal-unsigned.apk` | 约 346 MB |
| `aab/ironfox-<版本>.aab` | 约 349 MB |

本地签名：

```
apksigner sign --ks <keystore> --out <输出.apk> <未签名.apk>
```

IronFox 自己的 `sign.sh` 也是直接对这个文件执行 `apksigner sign`，没有额外的 zipalign。

**为什么要绕一下才能得到未签名的 APK：** IronFox 在不签名（`IRONFOX_SIGN=0`）时不会给 Gradle 加 `-PdisableDebugSigning`，Gradle 就会按 Fenix 的默认行为（`build.gradle` 里写明“本地构建就用 debug 签名”）用 debug 密钥签名，产物文件名带 `-debug-signed`。那把 debug 密钥是 runner 上现生成的，每次构建都不同，没法覆盖安装上一次的版本。而 `IRONFOX_SIGN` 不能直接设置，它是 `env_common.sh` 根据 4 个 keystore 变量是否都有值推导出来的。所以工作流在不签名时给这 4 个变量占位值，让 IronFox 走 `IRONFOX_SIGN=1` 的路径（Gradle 产出 `-release-unsigned.apk`，复制到 `outputs/unsigned/`），再用 `skip-sign.sh` 替换 `sign.sh`，只跳过最后的签名。这 4 个变量除 `sign.sh` 外没有别处会读取内容。

勾选 `sign` 并配置 4 个 secret 时，走的是 IronFox 原本的签名流程：产物在 `outputs/apk/ironfox-<版本>-arm64-v8a.apk` 等，另外还会生成 `outputs/apks/ironfox-<版本>.apks`。

工作流默认只上传 arm64 APK；勾选 `upload_all` 才会上传其余全部产物。

## 卡住时怎么看诊断

`watchdog.sh` 判定“卡住”的条件是：连续一段时间里 CPU、网络、磁盘三项都没有明显变化（`get_sources` 默认 30 分钟，其余 20 分钟）。真在编译 CPU 一定在忙，真在下载网络一定在收，两者都不动基本就是在等一个永远不会来的东西。判定后日志里会出现可折叠的“卡住诊断”，依次是：

1. 进程树，以及每个没有子进程的相关进程的状态和等待点（`wchan`，例如 `anon_pipe_read` 是在读管道，`futex_*` 是在等锁）
2. 这些进程打开的文件、管道和连接，以及最近 4 秒的系统调用（`strace`）
3. 相关 Python 进程的调用栈（`py-spy`），mach 卡住时能直接看出卡在哪个函数哪一行
4. 网络连接和内核日志里的 OOM 记录

把这一段贴出来就能定位原因。想调整阈值可以改步骤里的 `DW_STALL_SECS`，其它可选参数见 `watchdog.sh` 开头的注释。

## 验证情况

**这次改动（补丁整套替换、prebuild 拆成三步）做过：**

- 取了 IronFox `v160.0`（提交与工作流里的期望一致）和 Firefox `FIREFOX_160_0_RELEASE` 的 `mobile/android`（Gecko 提交 `2887d9de…`，就是 IronFox 的 `get_sources` 使用的那个）。
- 按 `patches.yaml` 的顺序，用与 IronFox 相同的 `patch -p1 --no-backup-if-mismatch`，应用它主清单 132 个补丁中涉及 `mobile/android` 的 86 个（其余 46 个不涉及这个目录，没有应用），全部成功，得到「IronFox 打完补丁后」的源码。
- 7 个补丁在这份源码上：单独应用、按顺序全部应用、拿掉任意一个其余仍能依次应用，均在 `--fuzz=0` 下通过。其中 6 个与 Firefox 版的增删行逐文件比对完全一致（`0005` 是有意改写的）。
- 其中 6 个在原版 160.0 上也能套；`0005` 套不上原版，这正是 prebuild 要拆开的原因。
- 通读了 `prebuild-if.sh` 的 `prepare_firefox`、`prepare_ac`、`prepare_fenix`：补丁之后的 `sed` / `rm` / overlay 复制没有碰这 7 个补丁改动的行；overlay（Fenix 和 Android Components 共 251 个文件）里没有与补丁同路径的文件。
- 读了 `prebuild.sh` 按目标单独运行的逻辑：每次调用开头只删旧的 `finished-prebuild` 标记并加载辅助脚本，结尾只创建标记，没有会破坏分阶段运行的无条件动作；`firefox` 之后各目标的执行顺序与 `all` 一致。
- 21 个被改动的 Kotlin 文件，用 tree-sitter 解析，补丁前后的语法错误节点都是 0。
- `apply-custom-patches.sh`：放进 IronFox 目录的源码副本上演练过（用 IronFox 自己的 `env.sh` 取 Gecko 路径）。成功路径；以及重复运行的失败路径（报错、退出码 1、不改动源码树）；结果与上面逐文件比对的验证仓库完全一致。演练中发现并修掉一个问题：原先用的 `--batch` 会把已应用的补丁当成反向补丁撤销掉，现在用 `--forward`。
- `prebuild-rest.sh`：用 IronFox 真实的 `prebuild-if.sh` 加桩 `prebuild.sh` 测过。守卫通过且 8 个目标按序运行、日志按目标另存；模拟 `all` 新增目标、删除目标、写法变得解析不出来，都会报错且一个目标都不跑；`IRONFOX_NO_PREBUILDS=1` 会报错。
- 两个新脚本用 shellcheck、工作流用 actionlint 检查过，均无告警。

**这次改动没做过：**

- 没有编译。Kotlin 把警告当成错误（`allWarningsAsErrors`）；`0005` 沿用了 Firefox 版补丁里的 `@Suppress("UNUSED_PARAMETER")`，没有编译器确认是否足够。
- 拆开后的三步 prebuild 没有在 GitHub Actions 上跑过。沙箱里 `source scripts/env.sh` 能得到 `external/gecko`，Actions 里没有验证。
- 验证用的源码只含 `mobile/android`，不含 IronFox 补丁对其它目录的改动。这些改动与这 7 个补丁无关，但没有在完整的 Gecko 源码树上跑过。
- 没有在手机上装过，不知道 7 个补丁叠加后界面是否都正常，尤其是 `0005` 的菜单布局、`0007` 的标签页底部弹层，在 IronFox 额外的菜单项和页签条件下的显示。

**与这次改动无关、沿用之前的验证情况**（当时用的是旧流程：旧的 11 个补丁登记进 IronFox 的清单，prebuild 一步跑完）：

- 用 IronFox 的 `env.sh` 校验过工作流设置的环境变量（Ubuntu 24.04，识别为 `ubuntu`，Release 渠道下的产物文件名也核对过）。
- 下载校验、渠道判断、提交校验、签名准备、产物定位这几步在本地用模拟数据跑过。
- 在 GitHub 上用旧流程完整跑通过编译：`get_sources.sh`、`prebuild.sh`、`build.sh bundle` 全部成功，产出了上表里的 4 个 APK 和 AAB。随后「定位 arm64 APK」这一步因文件名带 `-debug-signed` 没匹配上而失败，已修正并加了兜底上传，后来又改成不再产出 debug 签名的 APK（见「产物与签名」）。
- 更早的一次跑到 `build.sh` 里的第一次 `mach configure`。mozconfig 加载失败的问题（dash 不认 `pipefail`）已在本地（Ubuntu 24.04）按 mach 的调用方式复现出同样的报错，并验证 `IRONFOX_SH=/bin/bash` 之后，bundle 和 arm64 两种架构下 ironfox-core、gecko（构建和打包阶段）、geckoview、android-components、fenix 各项目的 mozconfig 都能正常加载。
- 不签名路径按 IronFox 自己的逻辑在本地验证过：设置占位 keystore 变量后 `IRONFOX_SIGN` 变为 1，Fenix 的 mozconfig 给 Gradle 加上 `-PdisableDebugSigning`，未签名产物路径是 `outputs/unsigned/…-unsigned.apk`；`skip-sign.sh` 用 `build.sh` 同样的 `source … || exit 1` 方式测过能正常返回。
- 在 GitHub 上碰到过 Safe Browsing 密钥检查：`build.sh` 的环境检查要求 `IRONFOX_SB_GAPI_KEY_FILE` 指向一个存在的文件，否则本地模式会弹出确认提示，Actions 里没有终端可输入就直接中止。已在工作流里加了占位文件，并在本地复现了这个报错、验证了修法，也核对了 bundle 构建里 `IRONFOX_MACH_BUILD=0`、走的是 `--without-google-safebrowsing-api-keyfile`，文件内容不会被读取。

**一直没做过的：**

- 不签名路径（真正未签名的 APK）在 GitHub 上还没有跑过，所以 Gradle 实际产出的文件名是否就是 `app-*-release-unsigned.apk`，是按 IronFox 的脚本推断的；产物上传这一步（`upload-artifact`，不打包成 zip）也没有真正跑到过；`sign=true`（在 Actions 里用你的 keystore 签名）这条路径也没有跑过。`watchdog.sh` 在本地用模拟的卡死、阻塞读、下载等场景测过。
- 渠道检测没有在真实 AAR 上验证过。
- 官方 CI 用流水线创建时间统一各任务的构建时间戳（`IRONFOX_BUILD_DATE_OVERRIDE` 等），这里没有对齐。GeckoView 的 Java 侧构建 ID（`MOZ_APP_BUILDID`）在上游源码里只用于崩溃报告，没有运行时比较，所以影响应该很小，但没有实测。
