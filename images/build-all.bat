@echo off

pushd .

cd u\alpine\git-guardian
call build-local.bat

cd ..\..\ubi9\vm-emu\minimal
call build-local-pu.bat
call build-local-wmui.bat

cd ..\local-wmui
call build-local.bat

popd
