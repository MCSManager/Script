# Install MCSManager with Docker

## Prerequisites

You need to prepare the following before installation:

- `docker` version `17.12.0+` has been installed
- `docker-compose` has been installed

## Start installation

First, use the following command to create the basic directory of `docker-compose`

```bash
mkdir -p mcsmanager
cd mcsmanager
```

Then, create an empty file named `docker-compose.yaml`

```bash
touch docker-compose.yaml
```

If you are a new user, please copy the configuration file below, modify the part marked with comments, and paste it into `docker-compose.yaml`

If you cannot copy or paste this file, you can also click [here](https://github.com/MCSManager/Script/blob/master/docker/examples/cn/full.yaml) to get the sample file

```yaml
version: "2.4"

services:
  web:
    image: bluefunny/mcsm-web:latest
    volumes:
      # This is the MCSManager control panel log storage directory
      # The default is [/var/logs/mcsmanager/web]
      - /var/logs/mcsmanager/web:/logs

      # This is the MCSManager control panel log storage directory
      # The default is the data/web folder under the current directory
      - ./data/web:/data
    network_mode: host
    command: /start

  daemon:
    image: bluefunny/mcsm-daemon:latest
    volumes:
      # This is the MCSManager control panel log storage directory
      # The default is [/var/logs/mcsmanager/daemon]
      - /var/logs/mcsmanager/daemon:/logs

      # This is the MCSManager control panel log storage directory
      # The default is the data/daemon folder under the current directory
      - ./data/daemon:/data
    network_mode: host
    command: /start
```

If you are an old user and only plan to install a certain component of MCSManager (such as only installing the MCSManager daemon), please refer to the following two sample files and modify the part marked with comments

- [MCSManager web](https://github.com/MCSManager/Script/blob/master/docker/examples/cn/web.yaml)
- [MCSManager daemon](https://github.com/MCSManager/Script/blob/master/docker/examples/cn/daemon.yaml)

After all the above operations are completed, please run the following command to start MCSManager

```bash
docker-compose -f docker-compose.yaml up -d
```

If everything runs normally, you can soon access `http://127.0.0.1:23333` to view the panel you just built!

If you modify (or update) the `docker-compose.yaml` file later, please move it back to the directory and run the following command to make the modification take effect

```bash
docker-compose up -d
