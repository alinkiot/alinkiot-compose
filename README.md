# AlinkIoT 一键部署

基于 Docker Compose 的 AlinkIoT 物联网平台一键部署方案，整合了后端服务、前端界面、关系型数据库与时序数据库。

## 分支说明

| 分支 | 说明 |
|------|------|
| `main` | 旧版本 |
| `dev2.0` | 全新架构的版本 |

> 请根据需要切换到对应分支后再进行部署，例如使用全新架构版本：
>
> ```bash
> git checkout dev2.0
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
> | `main` | `registry.cn-hangzhou.aliyuncs.com/uzyiot/alinkiot:dev-0.0.339` |
> | `dev2.0` | `registry.cn-hangzhou.aliyuncs.com/uzyiot/alinkiot:dev2.0-0.0.343` |

## 架构组成

`docker-compose.yaml` 中定义了以下四个服务，运行在同一个 `alink-network` 桥接网络内：

| 服务 | 镜像 | 说明 | 对外端口 |
|------|------|------|----------|
| `alink-mysql` | `mysql:8.0` | 业务数据库，存储平台配置、设备、用户等数据 | `3306` |
| `alink-tdengine` | `tdengine/tdengine:3.0.3.2` | 时序数据库，存储设备上报的时序数据 | `6030`、`6041`、`6043-6049`(TCP/UDP) |
| `alinkiot` | `registry.cn-hangzhou.aliyuncs.com/uzyiot/alinkiot:<分支对应版本>` | 平台核心后端服务（镜像 tag 以所在分支的 `docker-compose.yaml` 为准，详见上文「分支说明」） | `18888`(API)、`1883`(MQTT)、`8083`(MQTT over WS)、`6500` |
| `nginx` | `nginx:alpine` | 前端静态资源托管 + 反向代理 | `80` |

Nginx 将 `/iotapi` 反向代理到后端 `18888`、`/mqtt` 反向代理到后端 `8083`，前端页面从 `www/dist` 提供。

## 目录结构

```
alinkiot-compose/
├── docker-compose.yaml      # 编排文件
├── LICENSE                  # 授权文件（挂载进 alinkiot 容器）
├── config/
│   ├── nginx.conf           # Nginx 站点配置
│   └── etc/                 # AlinkIoT 后端配置（emqx.conf、证书、插件等）
├── init/
│   ├── mysql/backup.sql     # MySQL 初始化脚本（首次启动自动导入）
│   └── tdengine/init.sql    # TDengine 初始化脚本
├── www/
│   ├── dist/                # 前端静态资源（Nginx 根目录）
│   └── upload/              # 上传文件目录
└── log/                     # 各服务日志挂载目录（mysql / tdengine / nginx / alinkiot）
```

## 前提条件

- 已安装 **Docker**
- 已安装 **Docker Compose**

验证：

```bash
docker -v
docker-compose -v
```

## 一键安装

在项目根目录执行：

```bash
docker-compose up -d
```

首次启动时：

- MySQL 会自动执行 `init/mysql/` 下的 SQL 完成数据库初始化（`backup.sql`）。
- TDengine 会自动执行 `init/tdengine/init.sql` 创建数据库并设置 root 密码。

启动完成后访问：

- 平台前端：`http://<服务器IP>/`
- 后端 API：`http://<服务器IP>:18888/iotapi`

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
docker exec -it alink-tdengine taos
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

> `taosdump` 可在安装了 TDengine 客户端的宿主机执行，或进入 `alink-tdengine` 容器内执行：`docker exec -it alink-tdengine bash`。

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
docker exec alink-mysql sh -c 'mysqldump -u root -p"alinkiot" alinkiot' > backup.sql
```

#### 恢复 / 导入

将 SQL 文件放入 `init/mysql/` 目录可在**首次启动**时自动导入；对已运行实例手动导入：

```bash
docker exec -i alink-mysql sh -c 'mysql -u root -p"alinkiot" alinkiot' < backup.sql
```

## 常见操作速查

| 操作 | 命令 |
|------|------|
| 一键启动 | `docker-compose up -d` |
| 重启全部服务 | `docker-compose down && docker-compose up -d` |
| 查看状态 | `docker-compose ps` |
| 查看后端日志 | `docker-compose logs -f alinkiot` |
| 停止并移除容器 | `docker-compose down` |
| 停止并清空数据卷 | `docker-compose down -v`（危险） |
| 进入 TDengine CLI | `docker exec -it alink-tdengine taos` |
| 进入 MySQL CLI | `docker exec -it alink-mysql mysql -uroot -palinkiot` |
