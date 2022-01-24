@echo off

Title MCSManager-Web 自动更新

color 9
echo ######################################################
echo #                                                    #
echo #               MCSManager-Web 自动更新              #
echo #                  by 糯米(nuomiaa)                  #
echo #                                                    #
echo ######################################################
echo.
echo [-] 检查 Git 是否安装...

for /F %%i in ('git --version') ^
do (
    set vars1=%%i
)

echo.

if "%vars1%"=="git" (
    echo [-] Git 已安装
    echo.

    echo [-] 初始化 Git
    git init
    git remote add origin https://github.com.cnpmjs.org/mcsmanager/mcsmanager-web-production.git
    git fetch --all
    git reset --hard origin/master
    echo.

    echo [-] 正在拉取最新版本...
    git pull origin master

    echo [-] 更新完成！
) else (
    echo [x] Git 未安装，尝试使用 winget 安装...
    winget install --id Git.Git -e --source winget

    color 4
    echo [-] 安装进程已结束，请重新运行脚本检查安装！
    echo [-] 如 Git 安装失败，请手动安装 Git: https://git-scm.com/download/win
)


pause