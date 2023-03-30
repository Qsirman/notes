# MinGW编译

MinGW 7.3.0 x64 - Opencv 4.5.0 - Qt 5.13.2

1. 安装 MinGW-w64 并配置环境变量
2. 使用 CMake 生成 OpenCV 的 Makefile
打开 cmake-gui，设置源码和生成路径：

Where is the source code: E:/opencv_341/opencv/sources
Where to build the binaries: E:/opencv_341/opencv_mingw64_build
点击 Configure，设置编译器

Specify the generator for this project: MinGW Makefiles
Specify native compilers
Next
Compilers C: E:\MinGW-w64\x64-4.8.1-release-posix-seh-rev5\mingw64\bin\gcc.exe
Compilers C++: E:\MinGW-w64\x64-4.8.1-release-posix-seh-rev5\mingw64\bin\g++.exe
Finish
编译配置：

勾选 WITH_OPENGL
勾选 ENABLE_CXX11
不勾选 WITH_IPP
不勾选 ENABLE_PRECOMPILED_HEADERS
点击 Configure，Generate 生成 Makefile

3. 编译 OpenCV
```
E:
cd E:\opencv_341\opencv_mingw64_build
mingw32-make -j 8
mingw32-make install
```


# 错误列表

## temporary of non-literal type
mingw和opencv中某个子模块（大概率是libprotobuf）的版本不对应，重新选择对应的版本

## opencv gcc: error: long: No such file or directory
关闭CMake中的`OPENCV_ENABLE_ALLOCATOR_STATS`选项，好像和libprotobuf也有关系

## File too big
CMakeFiles\3.21.0-rc2\CMakeCXXCompiler.cmake中添加：

set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} "-O3") 

mingw32-make -j8不行的话换成 mingw32-make