# Ubuntu for xiaomi K20 Pro

## 项目简介
本项目旨在为小米K20 Pro（代号raphael）设备移植Ubuntu和Debian系统。通过本项目，您可以在小米K20 Pro上运行Linux桌面或服务器系统。

## 📋 目前工作

- ✅ Wi-Fi (2.4Ghz，5Ghz)
- ✅ 蓝牙 (文件传输，音频)
- ✅ USB (ssh，OTG)
- ✅ 电池
- ✅ 实时时钟
- ✅ 显示
- ✅ 触摸
- ✅ 手电筒 (LED及强度调节)
- ✅ GPU
- ✅ FDE

## 内核版本
- stable: 6.18.y

## 构建指南

### GitHub Actions 构建
本项目提供了以下GitHub Actions工作流，可以在GitHub上自动构建：
- 内核编译工作流：编译指定版本的内核，并生成deb包。
- Ubuntu Desktop 编译工作流：构建Ubuntu桌面镜像。
- Ubuntu Server 编译工作流：构建Ubuntu服务器镜像。
- Debian Desktop 编译工作流：构建Debian桌面镜像。
- Debian Server 编译工作流：构建Debian服务器镜像。

每个工作流都可以手动触发，并需要指定内核版本等参数。

## 刷机指南

1. 解锁Bootloader。
2. 刷入第三方Recovery（如TWRP）。
3. 通过fastboot刷入镜像。
- fastboot flash userdata rootfs.img
- fastboot flash cache xiaomi-k20pro-boot.img
- fastboot flash boot u-boot.img
4. 擦除dtbo分区。
- fastboot erase dtbo

## 感谢
- [@cuicanmx](https://github.com/cuicanmx) - 提供帮助以及创新思路
- [@map220v](https://github.com/map220v/ubuntu-xiaomi-nabu) - 原项目
- [@Pc1598](https://github.com/Pc1598) - sm8150-mainline-raphael内核维护
- [Aospa-raphael-unofficial/linux](https://github.com/Aospa-raphael-unofficial/linux) - 内核项目
- [sm8150-mainline/linux](https://gitlab.com/sm8150-mainline/linux) - 内核项目