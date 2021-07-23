# usb-imagewriter

自己用的工具，用来把img文件写入TF卡中。例如把树梅派系统img文件烧录进TF卡。 
和其他工具区别是支持批量烧录，可以一次刷很多。

- 用bash script实现，一般linux系统不需要安装其他依赖。
- 支持同时烧录多个SD卡。
- 支持自动查找出U盘或者SD卡（TF卡）。
- 支持自动卸载文件系统（umount）。
- 写入成功提示。
- 支持显示烧录速度和进度。

```
install.sh 烧录单个TF卡使用。
install-all.sh 同时烧录多个TF卡使用。
```
