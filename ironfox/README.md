# ironfox/ —— 叠加到 IronFox 上的补丁和脚本

配合 `.github/workflows/ironfox-build.yml` 使用。补丁是 `patches/` 里那一套的子集，已按 IronFox 的要求整理过。

## 目录

| 路径 | 作用 |
|---|---|
| `patches/` | 要叠加到 IronFox 上的补丁，按文件名字母序依次应用 |
| `register-patches.sh` | 把补丁复制进 IronFox 源码，并登记到它的 `scripts/patches.yaml` |
| `check-aar-channel.sh` | 判断 GeckoView 压缩包是 Release 还是 Nightly 渠道编的 |
| `watchdog.sh` | 包在长时间运行的命令外面：定期打印磁盘和负载，卡住时抓取诊断信息并终止，不再白等到 6 小时上限 |

## 补丁清单

**已包含**（11 个文件，对应原来的 12 个补丁）：0001+0012（已合并为一个文件）、0004、0005、0006、0007、0009、0011、0013、0014、0015、compact-main-menu。

**没有包含**（需要先在 IronFox 的代码上重做）：

| 补丁 | 原因 |
|---|---|
| 0002 menu-remove-items | 和 IronFox 的 `fenix-ironfox-ui.patch`、`fenix-liberate-webcompat-reporter.patch` 改同一处（`MainMenu.kt`、`MoreSettingsSubmenu.kt`）。其中“反馈网站问题”IronFox 已经整个移除，账户项只在登录后才显示 |
| 0003 remove-vpn-ui | 同样改 `MenuDialogFragment.kt` 里被 IronFox 动过的地方。IronFox 默认已把 VPN 入口藏在它自己的开关和账户登录后面，可能不需要再做 |
| 0008 main-menu-layout | 与 IronFox 的菜单改动冲突（`MainMenu.kt`） |
| 0010 main-menu-remove-default-browser-banner | 与 IronFox 的菜单改动冲突（`MenuDialogFragment.kt`） |
| 0016 tab-manager-actions-in-banner | 与 IronFox 的标签页改动冲突（`TabsTrayBanner.kt`） |
| 0017 tab-page-order-synced-first | IronFox 让“同步”页按是否登录账户动态显示、“普通”页按“始终隐私浏览”动态显示，这个补丁把页签顺序写死了，需要按它的逻辑重写 |
| coexist-custom-package | 按要求去掉。IronFox 构建时按渠道设置包名：Release 是 `org.ironfoxoss.ironfox`，Nightly 是 `org.ironfoxoss.ironfox.nightly` |

## 增加或替换补丁时的规则

1. **每个补丁必须能单独应用于上游原版源码。** IronFox 的 prebuild 先对每个补丁单独做 dry-run，任何一个失败就整体中止。依赖其它补丁的要合并成一个文件，`0001-0012-…` 就是这样合并出来的。
2. 应用顺序就是文件名字母序；文件名不能和 IronFox 自带补丁重名。
3. 补丁里的路径是相对源码根目录的（`mobile/android/…`），按 `-p1` 应用。

## 本机快速判断 AAR 渠道（不用等 Actions）

```bash
curl -fLO https://artifacts.ironfoxoss.org/ironfox/<流水线ID>/geckoview-arm64-v8a.zip
bash ironfox/check-aar-channel.sh geckoview-arm64-v8a.zip     # 输出 release / nightly / unknown
```

输出 `unknown` 表示没能检测出来（这个检测是按源码推断写的，没有在真实 AAR 上验证过），不代表是哪个渠道。

## 在 Ubuntu 上跑 IronFox 遇到的问题（工作流里都已处理）

IronFox 官方 CI 用 Fedora，文档说 Ubuntu 可以原生构建，但实际有这些坑：

| 现象 | 原因 | 处理 |
|---|---|---|
| `bootstrap.sh` 在 CI 里停住 | Ubuntu 分支的 `apt upgrade` 没带 `-y` | 工作流自己装依赖 |
| 读不到补丁清单 | apt 版 `yq` 是 Python 版，输出带引号 | 下载 mikefarah 版 `yq`，用 `IRONFOX_YQ` 指给它 |
| `build.sh` 开头报缺 `IRONFOX_SB_GAPI_KEY_FILE`，随后 `Aborting...` | 检查要求文件存在，否则本地模式弹出确认提示，Actions 里没有终端可输入 | 放占位文件（bundle 构建里 Gecko 不编译，文件内容不会被读取） |
| `mozconfig_loader: 4: set: Illegal option -o pipefail`，随后 mach 永远挂住 | IronFox 的 mozconfig 是 bash 写法，mach 用 PATH 里的 `sh` 执行它；Ubuntu 的 `sh` 是 dash | 设置 `IRONFOX_SH=/bin/bash`，并在 get_sources 之后自检 |
| 没有 `/usr/bin/clang` | 只装了 `clang-18` | 多装 `clang`（实测缺它时 `env.sh` 不报错，装上更保险） |

mach 159 在 mozconfig 加载失败后会挂住的原因：它退出前要等一个“遥测初始化完成”的信号，这个信号在后台回调里设置；回调里会再加载一次 mozconfig，同样失败，抛出的异常没被捕获，信号就永远设不上。这是 mach 在这条出错路径上的行为，没有环境变量能关掉它，所以才加了 `watchdog.sh` 兜底。

## 产物与签名

`build.sh bundle` 会在 `IronFox/outputs/` 下产出：

| 文件 | 大小（159.0.1，Release） |
|---|---|
| `apk/ironfox-<版本>-arm64-v8a-debug-signed.apk` | 约 166 MB |
| `apk/ironfox-<版本>-armeabi-v7a-debug-signed.apk` | 约 163 MB |
| `apk/ironfox-<版本>-x86_64-debug-signed.apk` | 约 173 MB |
| `apk/ironfox-<版本>-universal-debug-signed.apk` | 约 346 MB |
| `aab/ironfox-<版本>.aab` | 约 349 MB |

**文件名里的 `debug-signed` 是什么意思：** 不勾选 `sign` 时，IronFox 没有用你的密钥签名，但 Fenix 的 `build.gradle` 写明“本地构建就用 debug 签名”，所以 Gradle 用 debug 密钥签了名。这样的 APK 可以直接安装，但 debug 密钥是 runner 上现生成的，每次构建大概率都不同，没法覆盖安装上一次的版本。

想要稳定的签名有两条路：在本地用你自己的 keystore 重新签名（`apksigner sign --ks <keystore> --out <输出.apk> <输入.apk>`），或者在 Actions 里勾选 `sign` 并配置 4 个 secret。勾选 `sign` 后文件名不带 `-debug-signed`，另外还会生成 `apks/ironfox-<版本>.apks`。

工作流默认只上传 arm64 APK；勾选 `upload_all` 才会上传其余全部产物。

## 卡住时怎么看诊断

`watchdog.sh` 判定“卡住”的条件是：连续一段时间里 CPU、网络、磁盘三项都没有明显变化（`get_sources` 默认 30 分钟，其余 20 分钟）。真在编译 CPU 一定在忙，真在下载网络一定在收，两者都不动基本就是在等一个永远不会来的东西。判定后日志里会出现可折叠的“卡住诊断”，依次是：

1. 进程树，以及每个没有子进程的相关进程的状态和等待点（`wchan`，例如 `anon_pipe_read` 是在读管道，`futex_*` 是在等锁）
2. 这些进程打开的文件、管道和连接，以及最近 4 秒的系统调用（`strace`）
3. 相关 Python 进程的调用栈（`py-spy`），mach 卡住时能直接看出卡在哪个函数哪一行
4. 网络连接和内核日志里的 OOM 记录

把这一段贴出来就能定位原因。想调整阈值可以改步骤里的 `DW_STALL_SECS`，其它可选参数见 `watchdog.sh` 开头的注释。

## 验证情况

做过：
- 在上游 159.0.1 源码上，用 IronFox 自己的 `check_patches` 和 `apply_patches` 跑过：它的 132 个补丁加这里的 11 个，预检和依次应用全部通过，没有 `.rej`；有三个补丁带行号偏移提示，没有模糊匹配。
- 用 IronFox 的 `env.sh` 校验过工作流设置的环境变量（Ubuntu 24.04，识别为 `ubuntu`，Release 渠道下的产物文件名也核对过）。
- 工作流用 actionlint 和 shellcheck 检查过；下载校验、渠道判断、提交校验、签名准备、产物定位这几步在本地用模拟数据跑过。
- 在 GitHub 上完整跑通了编译：`get_sources.sh`、`prebuild.sh`（含补丁的预检和应用）、`build.sh bundle` 全部成功，产出了上表里的 4 个 APK 和 AAB。随后“定位 arm64 APK”这一步因文件名带 `-debug-signed` 没匹配上而失败（我把它当成了“未签名”的命名），已修正并加了兜底上传。
- 更早的一次跑到 `build.sh` 里的第一次 `mach configure` 时，说明 `get_sources.sh` 和 `prebuild.sh`（含补丁的预检和应用）已经通过。mozconfig 加载失败的问题（dash 不认 `pipefail`）已在本地（Ubuntu 24.04）按 mach 的调用方式复现出同样的报错，并验证 `IRONFOX_SH=/bin/bash` 之后，bundle 和 arm64 两种架构下 ironfox-core、gecko（构建和打包阶段）、geckoview、android-components、fenix 各项目的 mozconfig 都能正常加载。
- 在 GitHub 上还碰到过 Safe Browsing 密钥检查：`build.sh` 的环境检查要求 `IRONFOX_SB_GAPI_KEY_FILE` 指向一个存在的文件，否则本地模式会弹出确认提示，Actions 里没有终端可输入就直接中止。已在工作流里加了占位文件。我在本地用 IronFox 自己的检查逻辑复现了这个报错并验证了修法，也核对了 bundle 构建里 `IRONFOX_MACH_BUILD=0`、走的是 `--without-google-safebrowsing-api-keyfile`，文件内容不会被读取。

没做过：
- 产物上传这一步（`upload-artifact`，不打包成 zip）在这个工作流里还没有真正跑到过；`sign=true`（在 Actions 里用你的 keystore 签名）这条路径也没有跑过；也没有在手机上装过，不知道这 11 个补丁叠加后界面是否都正常。`watchdog.sh` 在本地用模拟的卡死、阻塞读、下载等场景测过。
- 渠道检测没有在真实 AAR 上验证过。
- 官方 CI 用流水线创建时间统一各任务的构建时间戳（`IRONFOX_BUILD_DATE_OVERRIDE` 等），这里没有对齐。GeckoView 的 Java 侧构建 ID（`MOZ_APP_BUILDID`）在上游源码里只用于崩溃报告，没有运行时比较，所以影响应该很小，但没有实测。
