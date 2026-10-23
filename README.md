# AlinkIoT 一键部署

基于 Docker Compose 的 AlinkIoT 物联网平台一键部署方案，整合了后端服务、前端界面、关系型数据库与时序数据库。

## 分支说明

| 分支 | 说明 |
|------|------|
| `main` | 全新架构的版本 |
| `dev` | 旧版本 |

> 请根据需要切换到对应分支后再进行部署，例如使用全新架构版本：
>
> ```bash
> git checkout main
> ```

> ⚠️ 不同分支使用的 `alinkiot` 后端镜像版本不同，且会随版本迭代更新。实际版本**以所在分支的 `docker-compose.yaml` 为准**，可执行以下命令查看：
>
> ```bash
> grep "alinkiot:" docker-compose.yaml
> ```
>
> 当前各分支参考版本（可能已更新）：
>
> | 分支 | alinkiot 镜像 |
> |------|---------------|
> | `main` | `registry.cn-hangzhou.aliyuncs.com/uzyiot/alinkiot:main-0.0.4` |
> | `dev` | `registry.cn-hangzhou.aliyuncs.com/uzyiot/alinkiot:dev-0.0.339` |

## 架构组成

`docker-compose.yaml` 中定义了以下服务，运行在同一个 `alink-network` 桥接网络内：

| 服务 | 镜像 | 说明 | 对外端口 |
|------|------|------|----------|
| `alinkiot-mysql` | `mysql:8.0` | 业务数据库，存储平台配置、设备、用户等数据 | `3306` |
| `alinkiot-tdengine` | `tdengine/tdengine:3.0.3.2` | 时序数据库，存储设备上报的时序数据 | `6030`、`6041`、`6043-6049`(TCP/UDP) |
| `alinkiot` | `registry.cn-hangzhou.aliyuncs.com/uzyiot/alinkiot:<分支对应版本>` | 平台核心后端服务（镜像 tag 以所在分支的 `docker-compose.yaml` 为准，详见上文「分支说明」） | `18888`(API)、`1883`(MQTT)、`8083`(MQTT over WS)、`6500` |
| `nginx` | `nginx:alpine` | 托管 `www/dist` 中的前端静态资源并反向代理 | `58080` |

运行根目录的 `install.sh`（Linux/macOS）或 `install.cmd`（Windows）时，会先从 GitHub Release 下载前端并解压到 `www/dist`，然后启动 Docker Compose 服务。Nginx 将该目录挂载到容器内的 `/var/www/html`，并将 `/iotapi` 反向代理到后端 `18888`、`/mqtt` 反向代理到后端 `8083`。

> ⚠️ 前端资源从 [alinkiot/alinkiot_dashboard](https://github.com/alinkiot/alinkiot_dashboard) 的 GitHub Release 下载，该仓库需为**公开（Public）**。

## 目录结构

```
alinkiot-compose/
├── docker-compose.yaml      # 编排文件
├── install.sh               # 下载前端并启动服务
├── install.cmd              # Windows 下载前端并启动服务
├── config/
│   ├── etc/                 # AlinkIoT 后端配置（emqx.conf、证书、插件等）
│   ├── nginx.conf           # Nginx 站点配置
├── init/
│   ├── mysql/backup.sql     # MySQL 初始化脚本（首次启动自动导入）
│   └── tdengine/init.sql    # TDengine 初始化脚本
├── www/
│   ├── dist/                # 安装脚本下载的前端静态文件
│   └── upload/              # 上传文件目录
└── log/                     # 各服务日志挂载目录（mysql / tdengine / nginx / alinkiot）
```

## 前提条件

- 已安装 **Docker**
- 已安装 **Docker Compose**
- Linux/macOS 使用 `install.sh` 时需安装 `curl` 和 `unzip`
- Windows 使用 `install.cmd`，需安装 Docker Desktop（含 Docker Compose）和 Windows PowerShell

查看 Docker / Compose 版本：

```bash
docker -v
docker compose version
```

## 一键安装

在项目根目录执行：

```bash
./install.sh
```

Windows 在项目目录双击 `install.cmd`，或在命令提示符中运行：

```bat
install.cmd
```

首次启动时：

- MySQL 会自动执行 `init/mysql/` 下的 SQL 完成数据库初始化（`backup.sql`）。
- TDengine 会自动执行 `init/tdengine/init.sql` 创建数据库并设置 root 密码。

启动完成后访问：

| 服务 | 地址 | 说明 |
|------|------|------|
| 平台前端 | `http://<服务器IP>:58080/` | Nginx 托管的 Web 控制台 |
| 后端 API（直连） | `http://<服务器IP>:18888/iotapi` | 后端 REST API 直接访问 |
| 后端 API（代理） | `http://<服务器IP>:58080/iotapi` | 经 Nginx 反向代理的 API 入口 |
| MQTT | `mqtt://<服务器IP>:1883` | 设备 MQTT 接入端口 |
| MQTT over WebSocket | `ws://<服务器IP>:8083/mqtt` | 设备 MQTT over WS 接入端口（经 Nginx 代理） |
| MQTT over WebSocket（直连） | `ws://<服务器IP>:8083` | 后端 MQTT over WS 直接访问 |

查看运行状态与日志：

```bash
docker-compose ps
docker-compose logs -f alinkiot
```

## 启动 / 重启 / 停止

```bash
# 重新拉起（先停后起，常用于更新配置或镜像后）
docker-compose down && docker-compose up -d

# 停止并删除所有容器
docker-compose down

# 停止并删除所有容器和数据卷（⚠️ 会清空 mysql_data、tdengine_data 等卷中的数据，不可逆）
docker-compose down -v
```

> ⚠️ `docker-compose down -v` 会删除数据卷，导致数据库数据全部丢失，仅在确认需要彻底清库时使用。

## 数据库运维

### TDengine

默认账号 `root`，初始化脚本设置的密码为 `a112345666`。

#### 手动初始化（如需重新执行）

```sql
CREATE DATABASE IF NOT EXISTS alinkiot;
ALTER USER root PASS 'a112345666';
```

进入容器执行：

```bash
docker exec -it alinkiot-tdengine taos
# 在 taos 命令行中粘贴上面的 SQL
```

#### 备份

```bash
taosdump -h localhost -P 6030 -D alinkiot -o /file/path
```

- `-D alinkiot`：指定要备份的数据库
- `-o /file/path`：备份输出目录

#### 导入

```bash
taosdump -i /file/path -h localhost -P 6030
```

- `-i /file/path`：指定备份数据所在目录

> `taosdump` 可在安装了 TDengine 客户端的宿主机执行，或进入 `alinkiot-tdengine` 容器内执行：`docker exec -it alinkiot-tdengine bash`。

### MySQL

`docker-compose.yaml` 中默认配置：

- root 密码：`alinkiot`
- 业务库：`alinkiot`
- 业务账号：`alinkiot` / 密码 `a112345666`

#### 备份

```bash
mysqldump -u root -p alinkiot > backup.sql
```

执行后按提示输入 root 密码，`alinkiot` 为库名，导出到当前目录 `backup.sql`。

进入容器执行（宿主机未装 mysql 客户端时）：

```bash
docker exec alinkiot-mysql sh -c 'mysqldump -u root -p"alinkiot" alinkiot' > backup.sql
```

#### 恢复 / 导入

将 SQL 文件放入 `init/mysql/` 目录可在**首次启动**时自动导入；对已运行实例手动导入：

```bash
docker exec -i alinkiot-mysql sh -c 'mysql -u root -p"alinkiot" alinkiot' < backup.sql
```

## 更新前端版本

前端版本由 `install.sh` / `install.cmd` 中的 `FRONTEND_URL` 默认值控制。也可以通过环境变量临时指定下载地址：

更新步骤：

用目标 Release 地址重新运行安装脚本：

```bash
FRONTEND_URL=https://github.com/alinkiot/alinkiot_dashboard/releases/download/v0.0.2/dist.zip ./install.sh
```

Windows 命令提示符：

```bat
set "FRONTEND_URL=https://github.com/alinkiot/alinkiot_dashboard/releases/download/v0.0.2/dist.zip"
install.cmd
```
## 常见操作速查

| 操作 | 命令 |
|------|------|
| 一键下载前端并启动（Linux/macOS） | `./install.sh` |
| 一键下载前端并启动（Windows） | `install.cmd` |
| 重启全部服务 | `docker-compose down && docker-compose up -d` |
| 查看状态 | `docker-compose ps` |
| 查看后端日志 | `docker-compose logs -f alinkiot` |
| 更新前端版本（Linux/macOS） | `FRONTEND_URL=<下载地址> ./install.sh` |
| 更新前端版本（Windows） | 设置 `FRONTEND_URL` 后运行 `install.cmd` |
| 停止并移除容器 | `docker-compose down` |
| 停止并清空数据卷 | `docker-compose down -v`（危险） |
| 进入 TDengine CLI | `docker exec -it alinkiot-tdengine taos` |
| 进入 MySQL CLI | `docker exec -it alinkiot-mysql mysql -uroot -palinkiot` |

## 技术支持

部署或使用过程中遇到问题，欢迎通过以下方式联系获取支持：

| 助手微信 | 公众号 |
|:---:|:---:|
| <img src="docs/images/assistant-qrcode.png" width="180" alt="助手微信二维码" /> | <img src="docs/images/official-account-qrcode.jpg" width="180" alt="公众号二维码" /> |
| 扫码添加助手微信 | 扫码关注公众号 |
