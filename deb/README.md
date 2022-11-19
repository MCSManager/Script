此部分主要为 MCSManager 在 Debian/Ubuntu 系统上的发布版的源码

本部分分为两个模块, `deb` 和 `src`
`pack`: 编译模块, 此模块内的一级文件夹为架构名称, 编译时除 `一级文件夹\DEBIAN\control` 文件不会改变以外, 其他文件均由 `src` 模块内的所有文件覆盖, 如需编辑源码请见下面的 `src` 模块介绍
`src`: 源码模块, 此模块内的所有文件在编译阶段会覆盖掉 `pack` 模块内所有文件

如果你需要将此部分源码打包成可以直接使用 `apt` 或 `dpkg` 等工具可直接安装的 `deb` 程序包的话, 你需要先安装 `dpkg`, 然后运行以下命令

```bash
git clone https://github.com/MCSManager/Script.git
cd Script/deb/pack
bash build.sh
```

当显示 `Build complete` 时证明构建已成功, `build.sh` 同文件夹内应该会出现不同架构的 `deb` 程序包