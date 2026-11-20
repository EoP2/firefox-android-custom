# ironfox/ —— 叠加到 IronFox 上的补丁和脚本

配合 `.github/workflows/ironfox-build.yml` 使用。补丁是针对 **IronFox v160.0（Firefox 160.0）** 写的，打在 IronFox 自己的补丁**之后**；升级到 **v160.0.1（Firefox 160.0.1）** 后重新验证过，补丁文件没有改动（见「验证情况」）。它们是 `firefox-android-custom` 那套补丁里挑出来、并按 IronFox 的源码改写过的一部分；之前的补丁整套作废，已被替换。

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

**已包含（8 个）。** 每个补丁做什么、为什么这样做，见 Firefox 那份 README 里的同名小节；这里只写和 IronFox 有关的部分。

| 补丁 | 内容 | 与 Firefox 版的差异 |
|---|---|---|
| `0001-address-bar` | 地址栏改回旧版样式：40dp 高、4dp 圆角、盾牌图标间距收窄、搜索引擎按钮去掉下拉箭头 | 无 |
| `0002-context-menu` | 网页长按菜单：去掉「分享链接」「分享图片」、小圆角、标题边距收窄 | 无（原补丁里有一个上下文前 5 行后 3 行、不对称的 hunk，只能靠 fuzz 2 套上，重新生成后消除） |
| `0005-main-menu-content` | 主菜单的内容、布局和样式 | 见下 |
| `0006-main-menu-panel` | 主菜单面板：宽 200dp、靠右、不遮罩、无抓手、4dp 圆角，离屏幕右边和系统栏各留 8dp 外边距；**跟着工具栏走：地址栏在顶部时挂在状态栏下方，在底部时悬在导航栏上方** | 多了外边距、四个角都是圆角、顶部 / 底部两种位置；见下 |
| `0007-tab-manager-sheet` | 标签页管理改回底部弹层 | 无 |
| `0008-tab-list-classic-style` | 标签列表改回旧版平铺样式 | 无 |
| `0009-tab-manager-banner` | 标签页管理顶栏：搜索、新建、菜单三个悬浮按钮并进页签那一栏的最右边，悬浮按钮不再显示；页签靠左、每个固定宽度，底部不再为悬浮按钮留白 | 去掉了「对调私密和同步页签」；见下 |
| `compact-main-menu` | 主菜单行高压缩到 44dp / 48dp | 无 |

表里的「无」指增删的代码行与 Firefox 版逐文件相同，只是上下文按 IronFox 打完补丁后的源码重新生成。

**`0005` 与 Firefox 版的差异：**

- **账户入口：无条件去掉**，登录与否都不显示。IronFox 原本在启用账户功能并已登录时才显示它；这里连同 IronFox 加的 `if (isFxaSignedIn)` 包装一起删掉。`MainMenu` 的 `isFxaSignedIn` 参数保留但不再使用（该函数已有 `@Suppress("UNUSED_PARAMETER")`）。
- **密码入口：** 主菜单资料库里的 `showPasswords` 写死为 `false`，不管 IronFox 的「保存登录信息」设置是否开启都不显示。
- **去掉两处，因为 IronFox 已处理：** 「设为默认浏览器」横幅（IronFox 每次启动都把 `show_menu_banner` 置为 `false`）；「反馈网站问题」（IronFox 已把调用注释掉）。
- **书签 / 历史 / 下载那一排的位置**（Firefox 版是 书签、历史、下载 在前，后退、前进、刷新 在后，且不分工具栏位置，这里改了）。原则是：后退、前进、刷新总在靠工具栏的一侧，书签、历史、下载在另一侧：
  - 浏览页菜单，工具栏在顶部：页眉两排，第一排 后退、前进、刷新，第二排 书签、历史、下载。
  - 浏览页菜单，工具栏在底部或启用了「展开的工具栏」：书签、历史、下载这一排放进页眉（菜单最上面），后退、前进、刷新单独留在页脚（菜单最下面，一排），给页脚让出的底部留白也从两排高度改成一排。
  - 主页菜单：这排图标原来排在「设置、扩展」之后（原版 Firefox 里也是排在「扩展」之后，并不在顶部），现在挪到最上面，图标顺序没动。
  - 自定义标签页菜单不受影响。

  为此 `MenuNavigation` 多了一个 `showNavigationButtons` 开关，关掉时只画书签、历史、下载；它里面按钮的顺序也改成后退、前进、刷新在前，书签、历史、下载在后。
- **其余照旧：** 分享、定制主页、扩展项小字、桌面版网站徽标的去除，设置移到扩展上方，导航栏只留图标，无块状背景，区块间距收窄。IronFox 没有处理这些（在它的补丁、脚本和 overlay 里都搜不到）。

**`0009` 与 Firefox 版的差异：**

- **去掉「对调私密和同步页签」：** `Page.kt` 整个不动，`TabPageBannerTabs` 里的两处重排也不做。页签顺序保持 IronFox 原样：私密 | 普通 | 标签组 | 同步（同步页要登录账户才有，普通页在「始终隐私浏览」时没有）。
- **按 IronFox 的代码改写了两处：** `TabsTrayBanner` 把 `actions` 传给 `TabPageBanner` 时，放在 IronFox 加的 `showFxa`、`showNormalTabs` 之后；页签栏的最大宽度是「每个页签的宽度 × 页签个数」，个数用 IronFox 的三参数 `Page.visiblePages(…)` 取，所以同步页或普通页不显示时，页签的宽度和位置仍然正确。
- 其余（`TabManagerFloatingToolbar` 的改造、`TabsTray` 里去掉悬浮按钮槽、底部留白改 0dp）照旧，增删行与 Firefox 版相同。

**`0006` 与 Firefox 版的差异：**

- **外边距：** 面板离屏幕右边留 8dp；上下方向离系统栏也留 8dp（在底部时离导航栏上沿，在顶部时离状态栏下沿），不再贴边。想调整就改 `dimens.xml` 里的 `main_menu_sheet_margin`。
- **位置跟着工具栏：** 挂在顶部还是坐在底部，由新增的 `MenuSheetPlacement.kt` 里的 `Settings.isMenuAtTop(accessPoint)` 决定：地址栏在顶部就挂在顶部，在底部就在底部。启用「展开的工具栏」时菜单按钮在屏幕底部的导航栏里，所以算在底部，这与 `0005` 里「后退 / 前进 / 刷新放页脚」的条件一致；自定义标签页的菜单只看地址栏位置，与 `CustomTabMenu` 一致。只想看地址栏位置的话，把 `isMenuAtTop` 的返回值改成 `!shouldUseBottomToolbar`（`accessPoint` 参数随之没用了，函数上要加 `@Suppress("UNUSED_PARAMETER")`，否则警告会被当成错误；另外 `0005` 里页眉 / 页脚的条件不会跟着变，展开的工具栏下菜单内部的排列会和面板位置不一致）。
- **挂在顶部的做法：** 「适应内容」的底部弹层展开时总是贴着屏幕底部（展开位置 = 父高度 − 子高度）。顶部时 `hangFromTop()` 关掉 `isFitToContents`，展开位置就改成从顶部量起（`expandedOffset`，默认 0，下面说明由谁来设）；同时 `isDraggable = false`（没有可拖的方向，所以顶部时不能拖动收起，只能点外面或按返回键）。这一步最好在第一次布局之前做完：show 监听是在对话框显示之后才执行的（`0006` 原来把宽度提前到 `onStart()` 里设置，也是为了避免闪一下），那时第一次布局可能已经做过了，所以和宽度、gravity 一样放在 `onStart()` 里，show 监听里再做一次兜底。**顶部的外边距不能像底部那样用内边距做：** Material 的 `BottomSheetDialog` 里有个 `EdgeToEdgeCallback`，只要面板顶边还高于状态栏下沿，它就在每次布局之后把面板的顶部内边距改写成状态栏高度（底部内边距它不碰，所以底部的做法没事）。内边距里的那 8dp 会被它盖掉，内容就顶到状态栏下沿，看起来顶部没有边距。所以顶部是用面板的**位置**留边距：insets 监听里把 `expandedOffset` 设成「状态栏高度 + 外边距」（`hangBelowStatusBar()`），面板顶边不再高于状态栏下沿，Material 就只会把顶部内边距清成 0，背景也不用再缩进。`paddingTopSystemWindowInsets` 不管是 `true` 还是 `false`，展开偏移都等于这个值，不会叠加。面板高度上限也相应减去顶部外边距，否则横屏下面板底部会伸出屏幕 8dp。insets 监听是在 show 监听里装的，装完马上调一次 `requestApplyInsets`，保证它至少被调用一次。窗口动画也要换：底部弹层主题的进出场是从底部滑动，顶部时换成新增的 `MainMenuTopWindowAnimation`（`res/anim/main_menu_top_*.xml`，从顶部滑入、滑出）；Android 15+ 额外的回弹动画方向也反过来。
- **右边** 用 `CoordinatorLayout.LayoutParams` 的 `marginEnd`（`BottomSheetBehavior` 会按右外边距测量和定位）。
- **下边不能用 `bottomMargin`：** `BottomSheetBehavior` 定位时只看「父高度 − 子高度」，不看下外边距（Material 1.14.0 的源码里是这样）。所以改成：面板的底部内边距 = 导航栏高度 + 外边距，背景 drawable 用 `InsetDrawable` 在底部缩进同样的量，这样原来的背景和阴影都保留。每次系统栏 inset 变化（比如转屏）都会重新计算。
- **四个角都是圆角：** 背景 drawable 和 Compose 里的形状都改成了四角圆角（半径还是 `main_menu_sheet_corner_radius`，目前 4dp），因为面板悬空后，不再贴着屏幕边缘。
- **点击行为：** 点面板右边的空隙会关闭菜单；点面板外侧那一条（在底部时是导航栏上方的外边距，在顶部时是状态栏和它下面的外边距）不会，它仍属于面板那一层，会把点击吞掉，和原来导航栏那一块的行为一致。
- 站点信息面板（`TrustPanelFragment`）不受影响，仍然贴边、有抓手、只有顶部圆角。`MenuDialogFragment` 和默认关闭的 `MenuFragment` 两处做了同样的修改。

**没有包含：**

| 补丁 | 原因 |
|---|---|
| `0003-remove-vpn-ui` | 按要求不做。IronFox 有「Enable Firefox VPN」开关，**默认是开**，只有登录 Mozilla 账户后 VPN 入口才会出现（主菜单、站点信息面板）；不想看到就在 IronFox 设置里手动关掉 |
| `0004-extensions-hide-recommended` | IronFox 已经去除：`a-c-disable-amo-collections.patch` 把 `AddonManager.getAddons()` 里获取推荐扩展的代码注释掉了，返回的只剩已安装和内置的扩展；扩展页的「推荐」分区和主菜单里的推荐扩展都只取「未安装」的，所以永远是空的 |
| `0009` 里「对调私密和同步页签」那一半 | 按要求不做（见上）。要做的话得按 IronFox 的动态页签逻辑重写 `Page.kt`、`TabsTrayBanner.kt` 的 `TabPageBannerTabs` |
| `coexist-custom-package` | 按要求暂不移植。IronFox 构建时按渠道设置包名：Release 是 `org.ironfoxoss.ironfox`，Nightly 是 `org.ironfoxoss.ironfox.nightly` |

## 补丁放在构建流程的哪一步

IronFox 的构建分三段：`get_sources.sh`（下载源码和工具链）→ `prebuild.sh`（**改源码**）→ `build.sh`（编译）。补丁属于「改源码」，要落在 prebuild 里。

`prebuild.sh` 里先后做这些事：先把 IronFox 自己的补丁打到 Firefox 源码上（`firefox` 目标），再准备 Android Components、Application Services、Fenix、Glean 等子项目。其中 `prepare_fenix` 会把 `app/src/main/res/` 和 `app/build.gradle` 备份到临时目录，而 `build.sh` 开头又把这两样**删掉，再用备份还原**。

这带来两个限制：

1. **不能登记进 IronFox 的补丁清单**（之前的做法）。IronFox 在应用任何补丁之前，先拿每个补丁在**原版**源码上试一遍，任何一个套不上就整体中止。`0005` 要删掉的账户入口，IronFox 已经改成了 `if (isFxaSignedIn) { … }`，`0005` 删的是改过的版本；`0009` 要改的页签栏，IronFox 在同一处加了 `showFxa`、`showNormalTabs` 两个参数。这两个补丁套不上原版。（其余 6 个补丁在原版上也能套。）
2. **不能等 prebuild 全部跑完再打。** `0001`、`0006`、`0007` 改了 `res/` 下的文件（`dimens.xml`、`nav_graph.xml`、新增的 drawable / 动画 / 样式），晚打会被备份冲掉。

所以把 prebuild 拆成三步，补丁夹在中间：

1. `prebuild.sh firefox`：IronFox 检查并应用它自己的补丁；
2. `apply-custom-patches.sh`：你的补丁打在上面；
3. `prebuild-rest.sh`：其余目标，包括备份 `res/`。

`prebuild.sh` 本来就支持按目标单独运行（`ac`、`fenix`、`firefox` 等），没有改 IronFox 的任何脚本。代价是 IronFox 以后如果改了 `all` 的组成，`prebuild-rest.sh` 里的目标清单要同步；脚本里有检查，不一致会直接报错而不是漏跑。

## 增加或替换补丁时的规则

1. 补丁是针对「IronFox 打完补丁之后」的源码写的，**不要求能套在原版上**；顺序就是文件名的字节序（`LC_ALL=C`）。
2. 路径相对 Gecko 源码根目录（`mobile/android/…`），按 `-p1` 应用，且 `--fuzz=0`：上下文必须完全对得上，只允许行号偏移。用 `git diff` 导出的补丁（对称的 3 行上下文）满足这一点；手工裁剪过上下文的补丁会失败。
3. 补丁之间应当彼此独立：拿掉任意一个，其余仍能依次应用（现有 8 个已验证）。
4. 要避开 `prepare_*` 在补丁之后用 `sed` 改的行。例如 `prepare_fenix` 会注释掉 `TabManagementFragment.kt` 里的 `TabsTrayTelemetryMiddleware`，还有一条替换 `googleg_standard_color_18` 的 `sed`（160.0 和 160.0.1 里都没有这个字符串，是空操作）。
5. 脚本要用 `--forward`，不要换成 `--batch`：`--batch` 遇到已应用的补丁会自动假设 `-R`，把它悄悄撤销掉，而且退出码是 0。

**这 8 个补丁是怎么生成的**（升级 IronFox 后重做时用得上）：

1. 取与 IronFox 同一提交的 Gecko 源码（它的 `get_sources` 用的那个，写在 `scripts/versions.sh` 的 `IRONFOX_GECKO_COMMIT`；Firefox 160.0 是 `2887d9de…`，160.0.1 是 `58fed86b…`），只需要 `mobile/android`；
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

**升级到 IronFox v160.0.1（Firefox 160.0.1）做过：**

- 核对版本：GitHub 镜像上的 `v160.0.1` 标签是 `e80a40fc…`，与工作流里的 `expected_commit` 一致；`scripts/versions.sh` 里的 Gecko 提交是 `58fed86b…`，就是 Mozilla 的 `FIREFOX_160_0_1_RELEASE`（160.0 的 `2887d9de…` 是 `FIREFOX_160_0_RELEASE`）。
- IronFox 自己 v160.0 → v160.0.1 的改动：补丁里只有 `fenix-disable-gms-fonts.patch` 动了（`FenixApplication.kt` 那一段的上下文重新生成了）；`scripts/` 里只有 `versions.sh` 变了（Gecko、microG、Rust、Node.js、npm、uv、Python、l10n 的版本和校验值），`prebuild-if.sh`、`prebuild.sh`、`build.sh`、`env*.sh`、`bootstrap.sh`、`get_sources*.sh`、`sign.sh`、`patches.sh` 都没改；其余是泰语翻译相关的文件和 README / CHANGELOG。
- Firefox 160.0 → 160.0.1 在 `mobile/android` 里改了 452 个文件，绝大部分是翻译。代码改动只有 android-components 的 `browser/icons`、`feature/app-links`、`feature/prompts`（文件选择器）、merino 清单和 Glean 示例应用，Fenix 的 `FenixApplication.kt`、`GleanHelper.kt`、`GleanMetricsService.kt`、`OnboardingScreen.kt`、`initial_experiments.json`，以及 Focus；这 8 个补丁改动的文件一个都不在里面，补丁里也没有引用这些文件里的类。
- 重建「IronFox 打完补丁后」的源码，方法见上面「这 8 个补丁是怎么生成的」：取 `FIREFOX_160_0_1_RELEASE` 的 `mobile/android`，按 `patches.yaml` 的顺序套 v160.0.1 的补丁。主清单 132 个补丁里涉及 `mobile/android` 的 86 个全部成功（其余 46 个不涉及）。用同样的方法重建了 v160.0 的作对照，两边的数字相同（其中 32 个补丁带 fuzz，是 IronFox 自己的补丁叠在一起造成的，与这 8 个补丁无关）。
- 用 `apply-custom-patches.sh` 原样跑这 8 个补丁：全部通过（`--fuzz=0 --forward`，先 dry-run），没有 `.rej`；单独应用、拿掉任意一个其余依次应用，也都通过；已经应用过的补丁再套一次会被拒绝（dry-run 失败），不会被悄悄撤销。
- 这 8 个补丁改动的 26 个已有文件，在 v160.0 和 v160.0.1 两份「IronFox 打完补丁后」的源码里**逐字节相同**；另外 5 个是 `0006` 新建的文件，与源码里的文件没有重名。所以补丁没有重新生成，文件原样沿用，下面各节对补丁行为的验证结论仍然适用。
- 6 个补丁在原版 160.0.1 上也能套，`0005` 和 `0009` 套不上，与 160.0 时相同。
- 补丁之后的 `sed` / `rm` / overlay：`googleg_standard_color_18` 在 160.0.1 里依然不存在（空操作）；`TabManagementFragment.kt` 里会被注释掉的 `TabsTrayTelemetryMiddleware`（import 和调用各一处）在 `0007` 之后原样还在，`0007` 没有碰它们；overlay 从 251 个变成 252 个（Fenix 156 个、Android Components 96 个，多出来的是泰语的引导页字符串），仍然没有与补丁同路径的文件，也没有落在菜单、标签页、工具栏、长按菜单目录下的文件。
- `0006` 相关的四个文件：IronFox 的补丁里，只有 `fenix-ironfox-ui.patch` 动过 `MenuDialogFragment.kt`；`MenuFragment.kt`、`MenuDialogBottomSheet.kt`、`dimens.xml` 它都没动（与 v160.0 相同）。
- `prebuild-rest.sh` 的守卫：用 v160.0.1 的 `prebuild-if.sh` 重新解析 `all` 的目标，与脚本里的清单一致。
- 24 个被改动的 Kotlin 文件，用 tree-sitter 解析，补丁前后的语法错误节点仍然都是 0。

**升级到 v160.0.1 没做过：**

- 没有编译，没有在手机上装，没有在 GitHub Actions 上跑过（与之前相同）。
- 工作流里的 `pipeline_id`（`3083165820`）没有核实：`artifacts.ironfoxoss.org` 和 GitLab 在验证环境里访问不了。换版本时请自己确认它对应 `v160.0.1` 那个提交，以及它是 Release 还是 Nightly 渠道（工作流有渠道检查，不一致会在下载之后立刻停下）。
- UnifiedPush-AC（1.0.8，提交 `1fc4832d…`，与 IronFox 钉住的一致，160.0 → 160.0.1 之间没变）的两个补丁 `a-c-unifiedpush.patch`、`fenix-unifiedpush.patch` 会在 `prepare_firefox` 里打到 Gecko 源码上。验证时没有套它们：它们托管在 Codeberg / GitLab，验证环境取不到内容，不知道改了哪些文件。它的 Fenix overlay 只有 `app/src/test/…` 下的测试文件，与这 8 个补丁不会重名。如果它们改到了这 8 个补丁的上下文，会在 `apply-custom-patches.sh` 那一步报错并指出是哪个补丁。
- 验证用的源码仍然只含 `mobile/android`。

**下次 IronFox 升级后怎么判断要不要改补丁：** 看这 8 个补丁改动的文件，在新旧两份「IronFox 打完补丁后」的源码里是否逐字节相同。相同就原样沿用（这次的情况）；不同就按上面「这 8 个补丁是怎么生成的」重做。另外看一眼 IronFox 的 `scripts/` 有没有改动（这次只有 `versions.sh`）：`prebuild-if.sh` 变了的话，要重新核对 `prebuild-rest.sh` 的目标清单和 `prepare_*` 里的 `sed`。

**后来的改动（`0006` 让主菜单跟着工具栏位置走：改了两个 Fragment，新增 `MenuSheetPlacement.kt`、两个动画和一个样式文件）做过：**

- 新 `0006` 在 `--fuzz=0`、`--forward` 下套得上：① 原版 Firefox 160 的源码；② 「IronFox 补丁之后 → `0001` → 新 `0006` → `0009`」这条顺序。后者只取与这几个文件有关的部分：IronFox v160.0 里只有 `fenix-ironfox-ui.patch` 动过 `MenuDialogFragment.kt`，而且在第 532 行之后；`MenuFragment.kt`、`MenuDialogBottomSheet.kt`、`dimens.xml` 它都没动。新旧 `0006` 里 `MenuDialogBottomSheet.kt`、drawable、`dimens.xml` 三段逐字节相同，所以与 `0001`、`0009` 的叠加关系没变。
- 用 `apply-custom-patches.sh` 同样的参数（`-p1 --fuzz=0 --forward --no-backup-if-mismatch`，先 dry-run）演练过：成功、没有 `.rej`；重复运行会报错，不会悄悄撤销。
- 改动后的四个 Kotlin 文件用 tree-sitter 解析，语法错误节点是 0。
- 对照 Material 1.14.0 的源码核实过：`BottomSheetBehavior.setFitToContents`、`setState` 在第一次布局之前调用是安全的；`fitToContents` 为 `false` 时展开偏移是 `max(expandedOffset, paddingTopSystemWindowInsets ? 0 : insetTop)`；`BottomSheetDialog` 的 `EdgeToEdgeCallback.onLayout` 会在面板顶边高于状态栏下沿时改写顶部内边距（这是第一版「顶部没有边距」的原因），Fenix 的 `DayNight.BottomSheetDialog` 主题继承自 `enableEdgeToEdge=true` 的 `ThemeOverlay.MaterialComponents.BottomSheetDialog`，没有覆盖，所以这个回调在 Fenix 里是生效的。

**后来的改动没做过：**

- 没有编译。Kotlin 把警告当成错误；新代码照着已有写法写，没有编译器确认。
- 没有在手机上看过。需要真机确认的：顶部时面板的位置和大小；进出场动画的方向（按代码推断：Android 14 及以下用窗口动画，15+ 在窗口动画之外叠加回弹动画）；打开的第一帧有没有闪一下（面板的最终位置是 show 监听里装的 insets 监听算出来的，可能晚于第一次布局：先在屏幕顶端，再落到状态栏下沿 8dp 处，被滑入动画盖住的程度没有实测）；顶部的边距是不是真的有 8dp，以及它和底部的边距看上去是否一样；展开的工具栏、横屏、自定义标签页下的位置；顶部时 `0005` 页眉里的后退 / 前进 / 刷新与面板位置是否对得上。

**整套替换补丁、prebuild 拆成三步那次改动（针对 v160.0）做过：**

- 取了 IronFox `v160.0`（提交与工作流里的期望一致）和 Firefox `FIREFOX_160_0_RELEASE` 的 `mobile/android`（Gecko 提交 `2887d9de…`，就是 IronFox 的 `get_sources` 使用的那个）。
- 按 `patches.yaml` 的顺序，用与 IronFox 相同的 `patch -p1 --no-backup-if-mismatch`，应用它主清单 132 个补丁中涉及 `mobile/android` 的 86 个（其余 46 个不涉及这个目录，没有应用），全部成功，得到「IronFox 打完补丁后」的源码。
- 8 个补丁在这份源码上：单独应用、按顺序全部应用、拿掉任意一个其余仍能依次应用，均在 `--fuzz=0` 下通过。其中 5 个与 Firefox 版的增删行逐文件比对完全一致（`0005`、`0006`、`0009` 是有意改写的）。
- 其中 6 个在原版 160.0 上也能套；`0005` 和 `0009` 套不上原版，这正是 prebuild 要拆开的原因。
- 通读了 `prebuild-if.sh` 的 `prepare_firefox`、`prepare_ac`、`prepare_fenix`：补丁之后的 `sed` / `rm` / overlay 复制没有碰这 8 个补丁改动的行；overlay（Fenix 和 Android Components 共 251 个文件）里没有与补丁同路径的文件。
- 读了 `prebuild.sh` 按目标单独运行的逻辑：每次调用开头只删旧的 `finished-prebuild` 标记并加载辅助脚本，结尾只创建标记，没有会破坏分阶段运行的无条件动作；`firefox` 之后各目标的执行顺序与 `all` 一致。
- 24 个被改动的 Kotlin 文件，用 tree-sitter 解析，补丁前后的语法错误节点都是 0。
- `apply-custom-patches.sh`：放进 IronFox 目录的源码副本上演练过（用 IronFox 自己的 `env.sh` 取 Gecko 路径）。成功路径；以及重复运行的失败路径（报错、退出码 1、不改动源码树）；结果与上面逐文件比对的验证仓库完全一致。演练中发现并修掉一个问题：原先用的 `--batch` 会把已应用的补丁当成反向补丁撤销掉，现在用 `--forward`。
- `prebuild-rest.sh`：用 IronFox 真实的 `prebuild-if.sh` 加桩 `prebuild.sh` 测过。守卫通过且 8 个目标按序运行、日志按目标另存；模拟 `all` 新增目标、删除目标、写法变得解析不出来，都会报错且一个目标都不跑；`IRONFOX_NO_PREBUILDS=1` 会报错。
- 两个新脚本用 shellcheck、工作流用 actionlint 检查过，均无告警。

**整套替换那次改动没做过：**

- 没有编译。Kotlin 把警告当成错误（`allWarningsAsErrors`）；`0005` 沿用了 Firefox 版补丁里的 `@Suppress("UNUSED_PARAMETER")`，没有编译器确认是否足够。
- 拆开后的三步 prebuild 没有在 GitHub Actions 上跑过。沙箱里 `source scripts/env.sh` 能得到 `external/gecko`，Actions 里没有验证。
- 验证用的源码只含 `mobile/android`，不含 IronFox 补丁对其它目录的改动。这些改动与这 8 个补丁无关，但没有在完整的 Gecko 源码树上跑过。
- 没有在手机上装过，不知道 8 个补丁叠加后界面是否都正常，尤其是 `0005` 的菜单布局（包括工具栏在底部时，书签 / 历史 / 下载在页眉、后退 / 前进 / 刷新在页脚同时出现的显示）、`0007` 的标签页底部弹层、`0009` 的页签栏加按钮，在 IronFox 额外的菜单项和页签条件下的显示；以及 `0006` 的外边距在手势导航和三键导航下离屏幕下沿的实际距离。

**与整套替换那次改动无关、沿用之前的验证情况**（当时用的是旧流程：旧的 11 个补丁登记进 IronFox 的清单，prebuild 一步跑完）：

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
