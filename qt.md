1. 图标设置：当使用qmake时，在.pro中添加 RC_ICONS = xxx.ico，添加后应用程序图标、快捷方式图标、桌面大型图标以及标题栏图标都会改变，这是最标准最方便的方法，不推荐在源码中设置

2. qcustomplot最好使用动态链接，不然每次都要重新编译一次，非常慢。动态链接库使用方法参考动态链接库使用案例.pro文件，主要要注意的是` QT += printsupport`、`LIBS += -L$$PWD/3rdparty/qcustomplot/lib/debug/ -lqcustomplotd2`以及`DEFINES += QCUSTOMPLOT_USE_LIBRARY`这三部分一定要有，第三部分最隐蔽，如果不加defines会造成无法connect