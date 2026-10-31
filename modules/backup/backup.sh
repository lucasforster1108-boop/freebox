#!/usr/bin/env bash
# ============================================================
# backup.sh —— 服务器一键备份脚本
#
# 流程: 打包指定目录 -> 生成 sha256 校验文件 -> 大文件自动分块
#       -> 通过 rclone 上传到网盘 -> 只保留最近 N 份旧备份自动清理
#
# 配置: 与本脚本同目录的 backup.conf（模板见 backup.conf.example）
# 用法: ./backup.sh        （手动运行，或挂到 cron 里定时运行）
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/backup.conf"

# 配置加载前只能用这个最简报错（日志文件此时还不存在）
die() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [错误] $*" >&2
  exit 1
}

# ---------- 1. 读取配置 ----------
[[ -f "$CONFIG_FILE" ]] || die "找不到配置文件: $CONFIG_FILE
请先执行: cp backup.conf.example backup.conf ，然后按模板说明修改里面的路径和 remote 名称。"

# shellcheck disable=SC1090
source "$CONFIG_FILE"

# 带默认值的配置项（backup.conf 里没写就用这里的默认值）
KEEP_COUNT="${KEEP_COUNT:-4}"          # 只保留最近几份备份
SPLIT_SIZE="${SPLIT_SIZE:-400M}"       # 单文件超过这个大小就自动分块，如 400M / 2G / 104857600(字节)
WORK_DIR="${WORK_DIR:-/tmp/vps-backup-work}"   # 本地临时工作目录（打包/分块用，跑完自动清理）
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"         # 日志目录

mkdir -p "$LOG_DIR" "$WORK_DIR"
LOG_FILE="$LOG_DIR/backup.log"

log() {
  local line="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$line" | tee -a "$LOG_FILE"
}

fail() {
  log "[错误] $*"
  exit 1
}

# 把 "400M" / "2G" / "104857600" 这类写法统一换算成字节数
size_to_bytes() {
  local input="${1^^}"
  if [[ "$input" =~ ^([0-9]+)([KMGT]?)$ ]]; then
    local num="${BASH_REMATCH[1]}" unit="${BASH_REMATCH[2]}"
    case "$unit" in
      "")  echo "$num" ;;
      K)   echo $(( num * 1024 )) ;;
      M)   echo $(( num * 1024 * 1024 )) ;;
      G)   echo $(( num * 1024 * 1024 * 1024 )) ;;
      T)   echo $(( num * 1024 * 1024 * 1024 * 1024 )) ;;
    esac
  else
    return 1
  fi
}

# ---------- 2. 环境与配置检查（任何一项不对，立刻停并说明原因） ----------
for cmd in tar sha256sum split rclone stat flock numfmt; do
  command -v "$cmd" >/dev/null 2>&1 || fail "缺少命令: $cmd ，请先安装后重试"
done

[[ -n "${REMOTE_NAME:-}" ]] || fail "配置项 REMOTE_NAME 未设置，请在 backup.conf 里填写 rclone 的 remote 名称"
[[ -n "${REMOTE_PATH:-}" ]] || fail "配置项 REMOTE_PATH 未设置，请在 backup.conf 里填写网盘上的备份目录"
[[ -n "${SOURCE_DIRS+x}" && ${#SOURCE_DIRS[@]} -gt 0 ]] || fail "配置项 SOURCE_DIRS 为空，没有要备份的目录"

for dir in "${SOURCE_DIRS[@]}"; do
  [[ -d "$dir" ]] || fail "源目录不存在: $dir ，请检查 backup.conf 里的 SOURCE_DIRS"
done

rclone listremotes | grep -Fxq "${REMOTE_NAME}:" \
  || fail "rclone 里找不到名为 '${REMOTE_NAME}' 的 remote，请先执行 rclone config 创建并完成网盘授权"

SPLIT_BYTES="$(size_to_bytes "$SPLIT_SIZE")" \
  || fail "SPLIT_SIZE 格式不正确: '$SPLIT_SIZE'（示例: 400M / 2G / 104857600）"

# 防止两个备份任务同时运行互相干扰
exec 9>"$SCRIPT_DIR/.backup.lock"
flock -n 9 || fail "已有一个备份任务正在运行，本次退出"

# ---------- 3. 打包 ----------
START_TS="$(date +%s)"
BACKUP_NAME="backup-$(date '+%Y%m%d-%H%M%S')"
TMP_DIR="$(mktemp -d "$WORK_DIR/backup.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
LOCAL_DIR="$TMP_DIR/$BACKUP_NAME"
mkdir -p "$LOCAL_DIR"
ARCHIVE="$LOCAL_DIR/$BACKUP_NAME.tar.gz"

log "========== 开始备份: $BACKUP_NAME =========="
log "源目录: ${SOURCE_DIRS[*]}"
log "正在打包...（tar 提示 Removing leading '/' 是正常现象，可忽略）"

if command -v pigz >/dev/null 2>&1; then
  tar -I pigz -cf "$ARCHIVE" "${SOURCE_DIRS[@]}" || fail "打包失败"
else
  tar -czf "$ARCHIVE" "${SOURCE_DIRS[@]}" || fail "打包失败"
fi

ARCHIVE_BYTES="$(stat -c %s "$ARCHIVE")"
log "打包完成: $(numfmt --to=iec "$ARCHIVE_BYTES")（${ARCHIVE_BYTES} 字节）"

# ---------- 4. 生成 sha256 校验文件（对完整压缩包，分块之前生成） ----------
( cd "$LOCAL_DIR" && sha256sum "$BACKUP_NAME.tar.gz" > "$BACKUP_NAME.tar.gz.sha256" ) \
  || fail "生成 sha256 校验文件失败"
log "sha256 校验文件已生成: $BACKUP_NAME.tar.gz.sha256"

# ---------- 5. 大文件自动分块 ----------
if (( ARCHIVE_BYTES > SPLIT_BYTES )); then
  log "压缩包超过 $SPLIT_SIZE，开始分块（每块 $SPLIT_SIZE）..."
  split -b "$SPLIT_SIZE" -d -a 3 "$ARCHIVE" "$ARCHIVE.part-" || fail "分块失败"
  rm -f "$ARCHIVE"
  PART_COUNT="$(find "$LOCAL_DIR" -name '*.part-*' -type f | wc -l)"
  log "分块完成: 共 $PART_COUNT 块"
else
  log "压缩包不超过 $SPLIT_SIZE，无需分块"
fi

# ---------- 6. 上传到网盘（每份备份一个独立的日期文件夹） ----------
REMOTE_DIR="$REMOTE_NAME:$REMOTE_PATH/$BACKUP_NAME"
log "开始上传到: $REMOTE_DIR"
rclone copy "$LOCAL_DIR" "$REMOTE_DIR" || fail "上传失败，请检查网络和 rclone 授权后重新运行（重新运行是安全的）"
log "上传命令执行完毕，正在核对文件数量..."

LOCAL_COUNT="$(find "$LOCAL_DIR" -type f | wc -l)"
REMOTE_COUNT="$(rclone lsf -R "$REMOTE_DIR" | wc -l)"
[[ "$LOCAL_COUNT" -eq "$REMOTE_COUNT" ]] \
  || fail "上传后文件数量不一致: 本地 $LOCAL_COUNT 个，远端 $REMOTE_COUNT 个，请重新运行脚本"
log "核对无误: 共 $REMOTE_COUNT 个文件"

# ---------- 7. 清理旧备份，只保留最近 KEEP_COUNT 份 ----------
log "检查旧备份（只保留最近 $KEEP_COUNT 份）..."
mapfile -t ALL_DIRS < <(
  rclone lsf "$REMOTE_NAME:$REMOTE_PATH" --dirs-only 2>/dev/null \
    | sed 's:/$::' | grep -E '^backup-[0-9]{8}-[0-9]{6}$' | sort || true
)
TOTAL="${#ALL_DIRS[@]}"
if (( TOTAL > KEEP_COUNT )); then
  REMOVE_COUNT=$(( TOTAL - KEEP_COUNT ))
  for (( i = 0; i < REMOVE_COUNT; i++ )); do
    OLD="${ALL_DIRS[$i]}"
    log "删除旧备份: $OLD"
    rclone purge "$REMOTE_NAME:$REMOTE_PATH/$OLD" || fail "删除旧备份 $OLD 失败（本次新备份已上传成功）"
  done
  log "清理完成: 删除 $REMOVE_COUNT 份旧备份，现共保留 $KEEP_COUNT 份"
else
  log "当前共 $TOTAL 份备份，无需清理"
fi

END_TS="$(date +%s)"
log "========== 备份成功: $BACKUP_NAME ，耗时 $(( END_TS - START_TS )) 秒 =========="
