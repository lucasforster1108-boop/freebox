#!/usr/bin/env bash
# =============================================================================
# AdGuard Home 卸载脚本（Ubuntu / Debian）
#
# 功能：停止并删除系统服务、删除程序目录，做到干净卸载。
# 特点：可重复运行（幂等）——未安装时运行也不会报错。
# 用法：sudo bash uninstall.sh
# =============================================================================

set -uo pipefail

INSTALL_DIR="/opt/AdGuardHome"          # 官方默认安装目录
SERVICE_NAME="AdGuardHome"              # 官方默认服务名
UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

info() { echo -e "\033[1;32m[进度]\033[0m $*"; }
warn() { echo -e "\033[1;33m[提示]\033[0m $*"; }
fail() { echo -e "\033[1;31m[错误]\033[0m $*" >&2; }

# ---------- 权限检查 ----------
if [ "$(id -u)" -ne 0 ]; then
    fail "请使用 root 权限运行本脚本，例如：sudo bash uninstall.sh"
    exit 1
fi

# ---------- 第 1 步：停止服务 ----------
if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
    info "正在停止服务 ${SERVICE_NAME}……"
    systemctl stop "${SERVICE_NAME}" || warn "停止服务时出现问题，继续执行后续步骤。"
else
    info "服务 ${SERVICE_NAME} 未在运行，跳过停止步骤。"
fi

# ---------- 第 2 步：通过官方方式注销服务 ----------
if [ -x "${INSTALL_DIR}/AdGuardHome" ]; then
    info "正在注销系统服务……"
    "${INSTALL_DIR}/AdGuardHome" -s uninstall >/dev/null 2>&1 || true
fi
# 兜底：手动禁用并删除可能残留的 unit 文件
systemctl disable "${SERVICE_NAME}" >/dev/null 2>&1 || true
if [ -f "${UNIT_FILE}" ]; then
    info "删除残留的服务文件 ${UNIT_FILE}……"
    rm -f "${UNIT_FILE}"
fi
systemctl daemon-reload 2>/dev/null || true
systemctl reset-failed "${SERVICE_NAME}" 2>/dev/null || true

# ---------- 第 3 步：删除程序目录 ----------
if [ -d "${INSTALL_DIR}" ]; then
    info "正在删除程序目录 ${INSTALL_DIR}……"
    rm -rf "${INSTALL_DIR}"
else
    info "程序目录 ${INSTALL_DIR} 不存在，跳过。"
fi

# ---------- 完成：说明残留数据位置 ----------
cat <<EOF

============================================================
✅ AdGuard Home 已卸载完成。

关于数据残留，请注意：
    1. 配置文件（AdGuardHome.yaml）与运行数据（过滤统计、查询日志等）
       默认都存放在 ${INSTALL_DIR} 内，已随程序目录一并删除；
    2. 若你曾把程序装到其他目录、或手动备份过配置文件，
       请自行检查并删除那些副本；
    3. 若安装时按 README 处理过 53 端口占用（例如停用过 systemd-resolved
       的 DNSStubListener），卸载后如需恢复系统默认 DNS 行为，
       请按你当时的修改手动改回；
    4. 别忘了把你的设备 / 路由器上的 DNS 地址改回原来的设置，
       否则设备可能无法正常上网解析域名。
============================================================
EOF
