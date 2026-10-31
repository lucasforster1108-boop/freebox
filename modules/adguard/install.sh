#!/usr/bin/env bash
# =============================================================================
# AdGuard Home 一键安装脚本（Ubuntu / Debian）
#
# 功能：调用 AdGuard Home 官方安装脚本完成安装，并注册为系统服务（开机自启）。
# 特点：可重复运行（幂等）——已安装时只检查状态，不会重复安装或报错。
# 用法：sudo bash install.sh
# =============================================================================

set -euo pipefail

# ---------- 基础变量 ----------
INSTALL_DIR="/opt/AdGuardHome"          # 官方默认安装目录
SERVICE_NAME="AdGuardHome"              # 官方默认服务名
SETUP_PORT="3000"                       # 首次设置向导 / 管理台默认端口
OFFICIAL_INSTALL_URL="https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh"

# ---------- 输出小工具 ----------
info() { echo -e "\033[1;32m[进度]\033[0m $*"; }
warn() { echo -e "\033[1;33m[提示]\033[0m $*"; }
fail() { echo -e "\033[1;31m[错误]\033[0m $*" >&2; }

# ---------- 第 0 步：权限检查 ----------
info "检查运行权限……"
if [ "$(id -u)" -ne 0 ]; then
    fail "请使用 root 权限运行本脚本，例如：sudo bash install.sh"
    exit 1
fi

# ---------- 第 1 步：系统检查 ----------
info "检查操作系统……"
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
        ubuntu|debian)
            info "当前系统：${PRETTY_NAME:-$ID}，符合要求。"
            ;;
        *)
            warn "当前系统为 ${ID:-未知}，本脚本仅在 Ubuntu / Debian 上测试过，继续运行可能失败。"
            ;;
    esac
else
    warn "无法读取 /etc/os-release，跳过系统检查。"
fi

# ---------- 第 2 步：幂等检查（已安装则直接报告状态） ----------
if [ -x "${INSTALL_DIR}/AdGuardHome" ]; then
    info "检测到 AdGuard Home 已安装在 ${INSTALL_DIR}，跳过安装步骤。"
    if systemctl list-unit-files "${SERVICE_NAME}.service" >/dev/null 2>&1 \
       && [ -n "$(systemctl list-unit-files "${SERVICE_NAME}.service" 2>/dev/null)" ]; then
        if systemctl is-active --quiet "${SERVICE_NAME}"; then
            info "服务 ${SERVICE_NAME} 正在运行中。"
        else
            info "服务未运行，正在启动……"
            systemctl start "${SERVICE_NAME}" || warn "服务启动失败，请运行 journalctl -u ${SERVICE_NAME} 查看日志。"
        fi
    else
        info "正在注册并启动系统服务……"
        "${INSTALL_DIR}/AdGuardHome" -s install || warn "服务注册失败，请查看上方输出。"
        systemctl start "${SERVICE_NAME}" || true
    fi
    # 已安装时同样打印访问信息，方便重复运行查看
    SKIP_INSTALL=1
else
    SKIP_INSTALL=0
fi

# ---------- 第 3 步：准备下载工具 ----------
if [ "${SKIP_INSTALL}" -eq 0 ]; then
    if ! command -v curl >/dev/null 2>&1; then
        info "未找到 curl，正在安装……"
        apt-get update -qq
        apt-get install -y -qq curl ca-certificates
    else
        info "下载工具 curl 已就绪。"
    fi
fi

# ---------- 第 4 步：调用官方脚本安装 ----------
if [ "${SKIP_INSTALL}" -eq 0 ]; then
    info "下载 AdGuard Home 官方安装脚本……"
    TMP_SCRIPT="$(mktemp)"
    # 退出时自动清理临时文件
    trap 'rm -f "${TMP_SCRIPT}"' EXIT
    curl -fsSL "${OFFICIAL_INSTALL_URL}" -o "${TMP_SCRIPT}"

    info "执行官方安装脚本（下载程序 + 注册系统服务）……"
    sh "${TMP_SCRIPT}" -v

    info "确认服务状态……"
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        info "服务 ${SERVICE_NAME} 已启动，并已设为开机自启。"
    else
        systemctl start "${SERVICE_NAME}" || warn "服务尚未运行，请运行 journalctl -u ${SERVICE_NAME} 查看原因。"
    fi
fi

# ---------- 第 5 步：53 端口占用提醒 ----------
# Ubuntu 桌面/服务器自带的 systemd-resolved 可能占用 53 端口，导致 AdGuard Home 无法监听。
# 这里只做提醒、不擅自改系统设置，具体处理见 README「常见问题」第 1 条。
if command -v ss >/dev/null 2>&1; then
    if ss -lntup 2>/dev/null | grep -E '[:.]53[[:space:]]' | grep -qv 'AdGuardHome'; then
        warn "检测到 53 端口可能被其他程序占用（如 systemd-resolved）。"
        warn "若向导完成后 DNS 不工作，请按 README「常见问题」第 1 条处理。"
    fi
fi

# ---------- 完成：打印访问地址与下一步 ----------
SERVER_IP_HINT="<你的服务器IP>"
cat <<EOF

============================================================
✅ AdGuard Home 安装完成！

管理台（首次设置向导）地址：
    http://${SERVER_IP_HINT}:${SETUP_PORT}

下一步（在浏览器里完成向导）：
    1. 打开上面的地址，进入首次设置向导；
    2. 管理员界面端口保持默认（3000），DNS 服务器端口保持默认（53）；
    3. 设置一个管理员用户名和强密码（请妥善保存，脚本不会记录它）；
    4. 按向导提示，把你的设备或路由器 DNS 改为这台服务器的地址；
    5. 进入管理台后，建议按 README「推荐设置」配置上游 DNS 与过滤规则。

常用命令：
    查看状态： systemctl status ${SERVICE_NAME}
    重启服务： systemctl restart ${SERVICE_NAME}
    查看日志： journalctl -u ${SERVICE_NAME} -f
============================================================
EOF
