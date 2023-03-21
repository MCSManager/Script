# 通过 Docker 安装 MCSManager

## 预先准备

你需要提前做好以下几点准备

- 已经安装了 `17.12.0+` 版本的 `docker`
- 已经安装了 `docker-compose`

## 开始安装

首先, 请先使用以下命令创建 `docker-compose` 基本目录

```bash
mkdir -p mcsmanager
cd mcsmanager
```

然后, 创建一个名为 `docker-compose.yaml` 的空文件

```bash
touch docker-compose.yaml
```

如果你是一个新用户, 请复制下面的配置文件, 修改其中注释标出的部分, 粘贴到 `docker-compose.yaml` 中即可

如果你无法复制或粘贴此文件, 你也可以[点击此处](https://github.com/MCSManager/Script/blob/master/docker/examples/cn/full.yaml)获取示例文件

```yaml
version: "2.4"

services:
  web:
    image: bluefunny/mcsm-web:latest
    volumes:
      # 此处为 MCSManager 控制面板日志存储目录
      # 默认为 [/var/logs/mcsmanager/web]
      - /var/logs/mcsmanager/web:/logs

      # 此处为 MCSManager 控制面板日志存储目录
      # 默认为当前目录下的 data/web 文件夹
      - ./data/web:/data
    network_mode: host
    command: /start

  daemon:
    image: bluefunny/mcsm-daemon:latest
    volumes:
      # 此处为 MCSManager 控制面板日志存储目录
      # 默认为 [/var/logs/mcsmanager/daemon]
      - /var/logs/mcsmanager/daemon:/logs

      # 此处为 MCSManager 控制面板日志存储目录
      # 默认为当前目录下的 data/daemon 文件夹
      - ./data/daemon:/data
    network_mode: host
    command: /start
```

如果你是一个老用户, 并且只准备安装 MCSManager 的某个组件 (如仅安装 MCSManager 守护程序), 请查看下面这两个示例文件, 并修改其中注释标出的部分

- [MCSManager 控制面板](https://github.com/MCSManager/Script/blob/master/docker/examples/cn/web.yaml)
- [MCSManager 守护程序](https://github.com/MCSManager/Script/blob/master/docker/examples/cn/daemon.yaml)

当上述操作全部完成后, 请运行以下命令以启动 MCSManager

```bash
docker-compose -f docker-compose.yaml up -d
```

如果一切都运行正常, 那么不久后你就可以访问 `http://127.0.0.1:23333` 来查看你刚刚搭建好的面板了 !

如果你后期修改(或更新)了 `docker-compose.yaml` 文件, 请重新移动到该目录, 并运行以下命令以使修改生效

```bash
docker-compose up -d
```
