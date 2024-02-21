# 通过 Docker 安装 MCSManager

[English](README.md) | [简体中文](./README_cn.md)

## 预先准备

你需要提前做好以下两点准备

- 你使用的是 `Linux` 系统
- 已经安装了 `docker-ce` 软件包

> 由于 Windows 上的 Docker Desktop 实现方式并非常规, 因此, 我们不支持也不建议您在 Windows 系统上以 Docker 的方式安装 MCSManager

## 开始安装

首先, 请先切换为 root 用户

```bash
sudo su
```

然后使用以下命令创建一些待会儿会用到的基本目录

```bash
mkdir -p /opt/mcsmanager           # MCSManager 容器文件目录
mkdir -p /opt/mcsmanager/data      # MCSManager 数据文件目录
chown -R 1000:1000 /opt/mcsmanager # 修改目录权限
cd /opt/mcsmanager
```

然后, 创建一个名为 `docker-compose.yaml` 的空文件

```bash
touch docker-compose.yaml
```

如果你需要同时安装 MCSManager Web 与 MCSManager Daemon, 请复制下面的配置文件, 并将其粘贴到 `docker-compose.yaml` 中

```yaml
version: "3"

services:
  web:
    image: bluefunny/mcsmanager:web-9
    container_name: mcsmanager-web
    environment:
      - TZ=Asia/Shanghai
    volumes:
      # MCSManager Web 日志存储目录
      - ./data/logs/web:/opt/web/logs
      # MCSManager Web 数据存储目录
      - ./data/data/web:/opt/web/data
    # port:
    #   - 23333:23333 
    network_mode: host
    command: /entrypoint.sh

  daemon:
    image: bluefunny/mcsmanager:daemon-9
    container_name: mcsmanager-daemon
    environment:
      - TZ=Asia/Shanghai
    volumes:
      # MCSManager Daemon 日志存储目录
      - ./data/logs/daemon:/opt/daemon/logs
      # MCSManager Daemon 数据存储目录
      - ./data/data/daemon:/opt/daemon/data
    # port:
    #   - 24444:24444
    network_mode: host
```

> 如果你无法复制或粘贴此文件, 你也可以[点击此处](../examples/cn/full.yaml)获取示例文件

如果你只需要安装 MCSManager Web, 请复制下面的配置文件, 并将其粘贴到 `docker-compose.yaml` 中

```yaml
version: "3"

services:
  web:
    image: bluefunny/mcsmanager:web-9
    container_name: mcsmanager-web
    environment:
      - TZ=Asia/Shanghai
    volumes:
      # MCSManager Web 日志存储目录
      - ./data/logs/web:/opt/web/logs
      # MCSManager Web 数据存储目录
      - ./data/data/web:/opt/web/data
    # port:
    #   - 23333:23333 
    network_mode: host
```

> 如果你无法复制或粘贴此文件, 你也可以[点击此处](../examples/cn/web.yaml)获取示例文件

如果你要同时安装 MCSManager Daemon, 请复制下面的配置文件, 并将其粘贴到 `docker-compose.yaml` 中

```yaml
version: "3"

services:
  daemon:
    image: bluefunny/mcsmanager:daemon-9
    container_name: mcsmanager-daemon
    environment:
      - TZ=Asia/Shanghai
    volumes:
      # MCSManager Daemon 日志存储目录
      - ./data/logs/daemon:/opt/daemon/logs
      # MCSManager Daemon 数据存储目录
      - ./data/data/daemon:/opt/daemon/data
    # port:
    #   - 24444:24444
    network_mode: host
```

> 如果你无法复制或粘贴此文件, 你也可以[点击此处](../examples/cn/daemon.yaml)获取示例文件

当上述操作全部完成后, 请按需修改配置文件, 之后运行以下命令启动 MCSManager

```bash
docker compose -f docker-compose.yaml up -d
```

此时, 你只需要等待命令运行完毕即可完成安装

如果一切运行正常, 那么不久后你就可以访问 `http://127.0.0.1:23333` 来查看你刚刚搭建好的面板了 !

> 如果是在服务器上运行, 则请将 `127.0.0.1` 替换为你的公网 IP

> 如果你安装的是单独的的 MCSManager Daemon 程序, 则请将 `23333` 替换为 `24444`

## 卸载

如果后期你不需要 MCSManager 了, 你可以进入你用于放置 `docker-compose.yml` 的文件夹, 然后输入以下命令以卸载

```bash
docker compose -f docker-compose.yaml down
rm -rf data
```

---

至此, 你已完成了全部的任务, 现在你可以开始使用 MCSManager 了 !

不过如果你认为原本的 MCSManager Web 或 MCSManager Daemon 的镜像不够好, 你也可以自行编译

下面为一个简单的编译教程

---

## 自行编译

> 请注意, 你需要提前安装好 `docker-ce` 与 `python` 软件包, 并且你需要有一定的 Docker 使用经验

如果你需要自行编译, 你可以使用此目录中的 `build` 文件夹中的文件进行编译

- `Dockerfile-daemon` 为 MCSManager Daemon 的镜像构建文件
- `Dockerfile-web` 为 MCSManager Web 的镜像构建文件
- `entrypoint.sh` 为镜像默认执行的入口脚本, 在镜像启动时会运行此脚本
- `build.py` 为用于构建镜像的 Python 脚本, 使用 `python build.py -h` 以获取详细帮助

你可以使用以下命令构建镜像

```bash
python build.py build
python build.py build --push # 如果你需要将镜像推送到 Docker Hub, 注意: 这需要你自己预先配置好 Docker Registry
```

如果你不想使用 `build.py` 脚本, 你也可以使用以下命令构建镜像

```bash
docker build . -f <构建文件> -t <标签> # 例如: docker build . -f Dockerfile -t bluefunny/mcsmanager-daemon:9 --build-arg TYPE=daemon --build-arg VERSION=9
docker push <标签> # 如果你需要将镜像推送到 Docker Hub, 注意: 这需要你自己预先配置好 Docker Registry
```

在构建完成后, 你只需要将上文中配置文件中的 `image` 部分替换为你自行构建的镜像名称即可

## 致谢

构建脚本来源于 Fallen_breath 的个人仓库: https://github.com/Fallen-Breath/pterodactyl-eggs