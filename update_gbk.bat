@echo off

Title MCSManager-Web �Զ�����

color 9
echo ######################################################
echo #                                                    #
echo #               MCSManager-Web �Զ�����              #
echo #                  by Ŵ��(nuomiaa)                  #
echo #                                                    #
echo ######################################################
echo.
echo [-] ��� Git �Ƿ�װ...

for /F %%i in ('git --version') ^
do (
    set vars1=%%i
)

echo.

if "%vars1%"=="git" (
    echo [-] Git �Ѱ�װ
    echo.

    echo [-] ��ʼ�� Git
    git init
    git remote add origin https://github.com.cnpmjs.org/mcsmanager/mcsmanager-web-production.git
    git fetch --all
    git reset --hard origin/master
    echo.

    echo [-] ������ȡ���°汾...
    git pull origin master

    echo [-] ������ɣ�
) else (
    echo [x] Git δ��װ������ʹ�� winget ��װ...
    winget install --id Git.Git -e --source winget

    color 4
    echo [-] ��װ�����ѽ��������������нű���鰲װ��
    echo [-] �� Git ��װʧ�ܣ����ֶ���װ Git: https://git-scm.com/download/win
)


pause