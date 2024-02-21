# Installing MCSManager via Docker

[English](README.md) | [简体中文](./README_cn.md)

## Prerequisites

You need to have the following prerequisites ready beforehand:

- You are using a `Linux` system.
- `docker-ce` package is already installed.

> Due to the unconventional implementation of Docker Desktop on Windows, we neither support nor recommend installing MCSManager via Docker on Windows systems.

## Getting Started

Firstly, please switch to the root user.

```bash
sudo su
```

Then, create some basic directories that will be used later.

```bash
mkdir -p /opt/mcsmanager           # MCSManager container directory
mkdir -p /opt/mcsmanager/data      # MCSManager data directory
chown -R 1000:1000 /opt/mcsmanager # Modify directory permissions
cd /opt/mcsmanager
```

Next, create an empty file named `docker-compose.yaml`.

```bash
touch docker-compose.yaml
```

If you need to install both MCSManager Web and MCSManager Daemon simultaneously, please copy the configuration below and paste it into `docker-compose.yaml`.

```yaml
version: "3"

services:
  web:
    image: bluefunny/mcsmanager:web-9
    container_name: mcsmanager-web
    environment:
      - TZ=Asia/Shanghai
    volumes:
      # MCSManager Web logs directory
      - ./data/logs/web:/opt/web/logs
      # MCSManager Web data directory
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
      # MCSManager Daemon logs directory
      - ./data/logs/daemon:/opt/daemon/logs
      # MCSManager Daemon data directory
      - ./data/data/daemon:/opt/daemon/data
    # port:
    #   - 24444:24444
    network_mode: host
```

> If you are unable to copy or paste this file, you can also [click here](../examples/en/full.yaml) to get the example file.

If you only need to install MCSManager Web, please copy the configuration below and paste it into `docker-compose.yaml`.

```yaml
version: "3"

services:
  web:
    image: bluefunny/mcsmanager:web-9
    container_name: mcsmanager-web
    environment:
      - TZ=Asia/Shanghai
    volumes:
      # MCSManager Web logs directory
      - ./data/logs/web:/opt/web/logs
      # MCSManager Web data directory
      - ./data/data/web:/opt/web/data
    # port:
    #   - 23333:23333 
    network_mode: host
```

> If you are unable to copy or paste this file, you can also [click here](../examples/en/web.yaml) to get the example file.

If you want to install only MCSManager Daemon, please copy the configuration below and paste it into `docker-compose.yaml`.

```yaml
version: "3"

services:
  daemon:
    image: bluefunny/mcsmanager:daemon-9
    container_name: mcsmanager-daemon
    environment:
      - TZ=Asia/Shanghai
    volumes:
      # MCSManager Daemon logs directory
      - ./data/logs/daemon:/opt/daemon/logs
      # MCSManager Daemon data directory
      - ./data/data/daemon:/opt/daemon/data
    # port:
    #   - 24444:24444
    network_mode: host
```

> If you are unable to copy or paste this file, you can also [click here](../examples/en/daemon.yaml) to get the example file.

Once all the above operations are completed, modify the configuration file as needed, then run the following command to start MCSManager.

```bash
docker compose -f docker-compose.yaml up -d
```

Now, you just need to wait for the command to complete the installation.

If everything runs smoothly, shortly after, you can access `http://127.0.0.1:23333` to view the panel you just set up!

> If running on a server, replace `127.0.0.1` with your public IP.

> If you installed only the standalone MCSManager Daemon program, replace `23333` with `24444`.

## Uninstallation

If you no longer need MCSManager later on, you can navigate to the folder where you placed `docker-compose.yml` and then enter the following command to uninstall.

```bash
docker compose -f docker-compose.yaml down
rm -rf data
```

---

Congratulations! You have completed all the tasks, and now you can start using MCSManager!

However, if you find the original MCSManager Web or MCSManager Daemon images insufficient, you can also compile them yourself.

Below is a simple compilation tutorial.

---

## Self-Compilation

> Please note that you need to install `docker-ce` and `python` packages beforehand, and you need to have some Docker usage experience.

If you need to compile yourself, you can use the files in the `build` folder in this directory for compilation.

- `Dockerfile-daemon` is the image construction file for MCSManager Daemon.
- `Dockerfile-web` is the image construction file for MCSManager Web.
- `entrypoint.sh` is the default entry script executed in the image, which will run when the image starts.
- `build.py` is a Python script used to build images. Use `python build.py -h` to get detailed help.

You can use the following commands to build the images.

```bash
python build.py build
python build.py build --push # If you need to push the images to Docker Hub, note: this requires you to pre-configure Docker Registry yourself.
```

If you prefer not to use the `build.py` script, you can also use the following commands to build the images.

```bash
docker build . -f <build file> -t <tag> # For example: docker build . -f Dockerfile -t bluefunny/mcsmanager-daemon:9 --build-arg TYPE=daemon --build-arg VERSION=9
docker push <tag> # If you need to push the images to Docker Hub, note: this requires you to pre-configure Docker Registry yourself.
```

After the build is complete, you just need to replace the `image` section in the configuration files mentioned above with the name of the image you built yourself.

## Acknowledgements

The script was adapted from the personal repository of Fallen_breath: https://github.com/Fallen-Breath/pterodactyl-eggs

### This article was translated by ChatGPT, there may be some errors, if you find these errors, please submit an Issue to let us know