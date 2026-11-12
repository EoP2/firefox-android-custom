#!/usr/bin/env bash
# 空操作版的签名脚本：不勾选 sign 时，工作流会用它替换 IronFox 的 scripts/sign.sh。
#
# 背景：IronFox 的 build.sh 在 IRONFOX_SIGN=1 时才会让 Gradle 加上 -PdisableDebugSigning（得到真正未签名的
# app-*-release-unsigned.apk，复制到 outputs/unsigned/），随后 source 这个 sign.sh 去签名。
# IRONFOX_SIGN=0 时 Gradle 会按 Fenix 的默认行为用 debug 密钥签名（文件名带 -debug-signed），不是我们想要的。
# 所以不签名时：照样走 IRONFOX_SIGN=1 的路径（靠 4 个占位的 keystore 变量打开），但把签名这一步换成什么都不做。
#
# build.sh 是 `source` 这个文件的，所以用 return；万一被直接执行，return 会报错，再退回 exit。
echo "跳过签名：未签名的 APK 保留在 ${IRONFOX_OUTPUTS_APK_UNSIGNED:-outputs/unsigned}/，请在本地用你自己的 keystore 签名"
# shellcheck disable=SC2317  # 被 source 时执行 return；被直接执行时才会走到 exit
return 0 2>/dev/null || exit 0
