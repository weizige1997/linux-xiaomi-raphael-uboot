#!/bin/sh
set -e  # 遇到错误立即退出

# 检查是否以 root 权限运行
if [ "$(id -u)" -ne 0 ]
then
  echo "rootfs can only be built as root"
  exit
fi

# 设置 Ubuntu 版本
UBUNTU_VERSION="noble"

# 创建根文件系统镜像
truncate -s 2G rootfs.img
mkfs.ext4 rootfs.img
mkdir rootdir
mount -o loop rootfs.img rootdir

# debootstrap生成镜像
debootstrap --arch=arm64 $UBUNTU_VERSION rootdir https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/

# 绑定系统目录
mount --bind /dev rootdir/dev
mount --bind /dev/pts rootdir/dev/pts
mount --bind /proc rootdir/proc
mount --bind /sys rootdir/sys

# 配置网络和主机名
echo "nameserver 1.1.1.1" | tee rootdir/etc/resolv.conf
echo "xiaomi-raphael" | tee rootdir/etc/hostname
echo "127.0.0.1 localhost
127.0.1.1 xiaomi-raphael" | tee rootdir/etc/hosts

# Chroot 安装步骤
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:\$PATH
export DEBIAN_FRONTEND=noninteractive

# 配置清华镜像源
cat > rootdir/etc/apt/sources.list << 'EOF'
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble-updates main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble-backports main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ noble-security main restricted universe multiverse
EOF

# 更新系统
chroot rootdir apt update
chroot rootdir apt upgrade -y

# 安装基础软件包
chroot rootdir apt install -y bash-completion sudo apt-utils ssh openssh-server nano network-manager systemd-boot initramfs-tools chrony curl wget locales tzdata language-pack-zh-hans

# 设置时区和语言
echo "Asia/Shanghai" > rootdir/etc/timezone
chroot rootdir ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
chroot rootdir locale-gen en_US.UTF-8 zh_CN.UTF-8
chroot rootdir update-locale LANG=en_US.UTF-8

# 配置动态语言切换（SSH使用中文，TTY使用英文）
cat > rootdir/etc/profile.d/99-locale-fix.sh << 'EOF'
# 如果是SSH连接，则使用中文
if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ]; then
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8
fi
EOF
chmod +x rootdir/etc/profile.d/99-locale-fix.sh

# 安装设备特定软件包
chroot rootdir apt install -y rmtfs protection-domain-mapper tqftpserv

# 修改服务配置
sed -i '/ConditionKernelVersion/d' rootdir/lib/systemd/system/pd-mapper.service

# 复制并安装内核包（从预下载的目录）
cp xiaomi-raphael-debs_$1/*-xiaomi-raphael.deb rootdir/tmp/
chroot rootdir dpkg -i /tmp/linux-xiaomi-raphael.deb
chroot rootdir dpkg -i /tmp/firmware-xiaomi-raphael.deb
rm rootdir/tmp/*-xiaomi-raphael.deb
chroot rootdir update-initramfs -c -k all

# 配置 fstab
echo "PARTLABEL=userdata / ext4 errors=remount-ro,x-systemd.growfs 0 1
PARTLABEL=cache /boot vfat umask=0077 0 1" | tee rootdir/etc/fstab

# 创建默认用户
echo "root:1234" | chroot rootdir chpasswd
chroot rootdir useradd -m -G sudo -s /bin/bash user
echo "user:1234" | chroot rootdir chpasswd

# 允许SSH root登录
echo "PermitRootLogin yes" | tee -a rootdir/etc/ssh/sshd_config
echo "PasswordAuthentication yes" | tee -a rootdir/etc/ssh/sshd_config

# 配置 Netplan 使用 NetworkManager
cat > rootdir/etc/netplan/01-network-manager-all.yaml << 'EOF'
network:
  version: 2
  renderer: NetworkManager
EOF

# 添加屏幕管理命令到全局bash配置
cat >> rootdir/etc/bash.bashrc << 'EOF'
# 屏幕管理命令
leijun() {
    if [ $(id -u) -eq 0 ]; then
        echo 1 > /sys/class/graphics/fb0/blank
    else
        echo 1 | sudo tee /sys/class/graphics/fb0/blank > /dev/null
    fi
    echo "屏幕已关闭"
}

jinfan() {
    if [ $(id -u) -eq 0 ]; then
        echo 0 > /sys/class/graphics/fb0/blank
    else
        echo 0 | sudo tee /sys/class/graphics/fb0/blank > /dev/null
    fi
    echo "屏幕已开启"
}
EOF

# 清理 apt 缓存
chroot rootdir apt clean

# 生成 boot 镜像
mkdir -p boot_tmp
wget https://github.com/GengWei1997/kernel-deb/releases/download/v1.0.0/xiaomi-k20pro-boot.img
mount -o loop xiaomi-k20pro-boot.img boot_tmp

# 复制 boot 文件
cp -r rootdir/boot/dtbs/qcom boot_tmp/dtbs/
cp rootdir/boot/config-* boot_tmp/
cp rootdir/boot/initrd.img-* boot_tmp/initramfs
cp rootdir/boot/vmlinuz-* boot_tmp/linux.efi

umount boot_tmp
rm -d boot_tmp

# 删除 wifi 证书
rm -f rootdir/lib/firmware/reg*

# 卸载所有挂载点
umount rootdir/sys
umount rootdir/proc
umount rootdir/dev/pts
umount rootdir/dev
umount rootdir

rm -d rootdir

# 设置文件系统 UUID
tune2fs -U ee8d3593-59b1-480e-a3b6-4fefb17ee7d8 rootfs.img

echo 'cmdline for legacy boot: "root=PARTLABEL=userdata"'

# 压缩 rootfs 镜像
7z a rootfs.7z rootfs.img