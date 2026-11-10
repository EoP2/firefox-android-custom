# ironfox/ —— 叠加到 IronFox 上的补丁和脚本

配合 `.github/workflows/ironfox-build.yml` 使用。补丁是 `patches/` 里那一套的子集，已按 IronFox 的要求整理过。

## 目录

| 路径 | 作用 |
|---|---|
| `patches/` | 要叠加到 IronFox 上的补丁，按文件名字母序依次应用 |
| `register-patches.sh` | 把补丁复制进 IronFox 源码，并登记到它的 `scripts/patches.yaml` |
| `check-aar-channel.sh` | 判断 GeckoView 压缩包是 Release 还是 Nightly 渠道编的 |

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

## 验证情况

做过：
- 在上游 159.0.1 源码上，用 IronFox 自己的 `check_patches` 和 `apply_patches` 跑过：它的 132 个补丁加这里的 11 个，预检和依次应用全部通过，没有 `.rej`；有三个补丁带行号偏移提示，没有模糊匹配。
- 用 IronFox 的 `env.sh` 校验过工作流设置的环境变量（Ubuntu 24.04，识别为 `ubuntu`，Release 渠道下的产物文件名也核对过）。
- 工作流用 actionlint 和 shellcheck 检查过；下载校验、渠道判断、提交校验、签名准备、产物定位这几步在本地用模拟数据跑过。
- 在 GitHub 上实际跑到了 `build.sh`，说明 `get_sources.sh` 和 `prebuild.sh`（含补丁的预检和应用）已经通过。`build.sh` 因为缺少 Safe Browsing 密钥文件而中止：它的环境检查要求 `IRONFOX_SB_GAPI_KEY_FILE` 指向一个存在的文件，否则本地模式会弹出确认提示，Actions 里没有终端可输入就直接中止。已在工作流里加了占位文件。我在本地用 IronFox 自己的检查逻辑复现了这个报错并验证了修法，也核对了 bundle 构建里 `IRONFOX_MACH_BUILD=0`、走的是 `--without-google-safebrowsing-api-keyfile`，文件内容不会被读取。

没做过：
- `build.sh` 里真正的编译、签名和产物上传，在 GitHub 上还没有跑通过；也没有在手机上装过。
- 渠道检测没有在真实 AAR 上验证过。
- 官方 CI 用流水线创建时间统一各任务的构建时间戳（`IRONFOX_BUILD_DATE_OVERRIDE` 等），这里没有对齐。GeckoView 的 Java 侧构建 ID（`MOZ_APP_BUILDID`）在上游源码里只用于崩溃报告，没有运行时比较，所以影响应该很小，但没有实测。
