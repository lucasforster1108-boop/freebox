# FreeBox —— 一台免费 VPS，装下整个自托管基地

我受够了「抢到一台免费 ARM 机器」和「它真的能干活」之间的鸿沟。所有
教程都停在一步空白 Ubuntu。FreeBox 是我抢到机器后装的那一套——就是我
自己免费机器上实跑了几个月的系统，打包成一条命令：

- **AdGuard Home**：全网去广告/去跟踪的过滤 DNS
- **SubHub**：从你的 x-ui 节点自动生成代理订阅链接，不用再手改分享链接
- **状态页**：指标、服务检查、手机上能点的控制按钮
- **Uptime Kuma**：监控 + Telegram 告警，服务挂了直接推到手机
- **每周备份**：打包、sha256 校验、分块、传出机器，只留最近 4 份
- **Cloudflare 隧道**：每个服务都有域名和 HTTPS，**入站端口一个不用开**

## 快速开始

需要：一台干净的 Debian/Ubuntu VPS（ARM 或 x86，多数模块 1GB 内存够）、
root，可选一个托管在 Cloudflare 的域名。

```bash
git clone https://github.com/<you>/freebox.git
cd freebox
cp config.example.env config.env   # 填你自己的域名和令牌
sudo ./install.sh                  # 全部模块
# 或者只装几个：
sudo ./install.sh adguard subhub backup
```

每个模块也能单独装——`modules/` 下每个文件夹都有自己的 README 和安装脚本。

## 模块一览

| 模块 | 你得到什么 |
|---|---|
| `adguard` | AdGuard Home 一键部署 + 卸载 |
| `subhub` | 订阅生成/分发：节点在 JSON 里描述一次，得到 `/令牌` 和 `/令牌/<分组>` 两类地址；远程节点数据库走 scp 拉取，失败自动用缓存 |
| `status` | 我自己在用的状态页（采集器 + 网页 + 可选控制 API） |
| `monitor` | Docker 版 Uptime Kuma，只绑本机，附 Telegram 通知配置步骤 |
| `backup` | 基于 rclone 的每周备份：打包 + sha256 + 400M 分块 + 只留最近 4 份 |
| `tunnel` | cloudflared 安装 + ingress 模板 + 我推荐的 Access 门禁做法 |

## 为什么是这几件

免费机器坏掉的方式都很固定：你忘了上面跑着什么（状态页）、它半夜悄悄
死了（监控）、备份把磁盘塞满（轮换）、一次证书续期让所有 HTTPS 站点
同时挂掉（证书链，见下）、节点一变订阅链接全烂（SubHub）。FreeBox 不是
六个工具拼一桌，是真金白银踩坑踩出来的疤。

## 已经替你交过的学费

- **证书**：有些 ACME 部署只装叶子证书。续期后浏览器看着正常、严格校验
  全挂。要用完整证书链。
- **cron 与时区**：改完系统时区，cron 可能还按旧时区派活，直到重启它。
  判断任务跑没跑看产物文件，别只看 crontab 在不在。
- **备份**：超过 1G 的整包别直传 Google Drive，会被掐断。分块（备份
  模块默认 400M）、逐块核对大小、再留第二个目的地。
- **Web 配置目录**：备份文件绝不能放在被通配 include 的目录里
  （比如 `sites-enabled/`），删掉的服务会从自己的备份里「复活」。
- **小内存机器**：一次只装一个，装完查一次 `free -h`。希望不是内存
  管理策略。

## 安全说明

- 服务尽量只绑 `127.0.0.1`，隧道才是门。
- SubHub 的令牌就是密码。状态页的控制 API 必须放在认证后面。管理类
  入口建议套 Cloudflare Access。
- `config.env`、令牌、节点数据库都已 gitignore，别手贱提交。

## 许可证

MIT。拿去用，把你的机器跑起来，坏了回来告诉我。
