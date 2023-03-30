# SPI原理

spi(Serial Peripheral Interface)是串行外设接口，最少只需要一根数据线来完成数据传输，速率也可以更高，SPI有标准SPI、3线（3wire）SPI、双线（dual）SPI和4线（quad）SPI三种接口，标准的SPI有CLK、CS、MOSI、MISO四根线，分别为时钟、片选、主机发送数据线、主机接收数据线。

SPI基本原理很简单，大致包含三种线：CLK、CS和data，CLK为时钟线，CS为片选线，data为数据线

写数据时，按照约定的模式（后面会讲）先拉低/高CS片选信号，然后在每个clock上升沿向外写数据，等写完后再拉高/低CS片选信号

读数据时，按照写数据的方式反着来，检测CS片选信号的上升/下降沿，等到沿信号来了之后，在每个clock的上升沿从数据线上读数据，等CS片选信号来一个下降/上升沿后，表示数据传输结束


# SPI Master/Slave 模式根源区别在哪

根据两端身份将他们分为Master和Slave模式，一般情况下一个Master下面可以挂载多个Slave，也就是可以控制多个slave，slave属于从设备，则它只能受控于CLK和CS而不能主动改变。说直白点也就是：slave只能写MISO，对于CLK、CS以及MOSI都只能读。

## 标准SPI
标准SPI有四根线，分别为CLK、CS、MOSI和MISO，可以同时读写1bit。

## 三线SPI（3wire-SPI）
三线SPI有三根线，只有一根数据线，也就是没有MOSI和MISO的分别，也就不能同时读写，为半双工协议。

## 双线SPI（dual）
dual的意思是两根数据线，和标准SPI不同的是，两根数据线均为双向，那么每一个clock下它就可以传输2bit数据

## 四线SPI（quad）
和dual类似，quad的意思是四根双向数据线，每个clock可以传输4bit数据

## SDR/DDR
SDR（single data rate）,DDR(double data rate)，区别在于SDR只在clock的上升沿/下降沿传输数据，DDR在clock的每个下降沿都会传输，理论传输速率提高一倍。

## Xilinx-SPI controller
Xilinx-SPI controller的寄存器具体配置方法参考ug585即可，需要注意：有一些高端功能需要打开Auto模式，其参数配置才有效，只写参数的寄存器没有用。

### 