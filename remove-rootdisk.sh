#!/bin/bash
#first_define_your_new_disk
newdisk="/dev/sdb"
pve_target="/tmp/newdisk"

errlog(){
	if [ $? != 0 ];then
		echo $1
		exit 0
	fi
}

mount_fstab(){
	echo "create fstab"
	efiboot=$(blkid "$newdisk"2|awk  '{print $2}'|sed "s/\"//g")
	echo "proc /proc proc defaults 0 0" > $pve_target/etc/fstab
	echo "$efiboot /boot/efi vfat defaults 0 0" >> $pve_target/etc/fstab
	rootboot=$(blkid "$newdisk"3|awk  '{print $2}'|sed "s/\"//g")
	echo "$rootboot / ext4 errors=remount-ro 0 1" >> $pve_target/etc/fstab
}

prepare_chroot(){
	echo "prepare chroot"
	mount -n -t tmpfs tmpfs $pve_target/tmp
	mount -n -t proc /proc  $pve_target/proc
	mount -n -o bind /dev  $pve_target/dev
	mount -n -o bind /dev/pts  $pve_target/dev/pts
	mount -n -t sysfs sysfs $pve_target/sys 
	mkdir $pve_target/mnt/hostrun
	mount --bind /run $pve_target/mnt/hostrun
	chroot $pve_target mount --bind /mnt/hostrun /run
}

clean_chroot(){
	echo "clean chroot"
	echo clean
	chroot $pve_target umount /run
    umount $pve_target/mnt/hostrun
	umount -l $pve_target/proc
	umount -l $pve_target/sys
    umount -l $pve_target/dev/pts
	umount -l $pve_target/dev
	umount -l $pve_target/boot/efi/
	umount -l $pve_target
}

grub_install(){
	echo "create efi boot"
	mkdir $pve_target/boot/efi 
	chroot $pve_target mount "$newdisk"2 /boot/efi || errlog "mount efidisk error !"
	chroot $pve_target update-grub || errlog "create grub error !"
	mkdir $pve_target/boot/efi/EFI/BOOT/ -p || errlog "create efiboot folder error !" 
	if [ `arch` = "aarch64" ];
	then
		chroot $pve_target grub-install --target arm64-efi --no-floppy --bootloader-id='proxmox' $newdisk  || errlog "grub install to $newdisk error !"
		cp $pve_target/boot/efi/EFI/proxmox/* $pve_target/boot/efi/EFI/BOOT/  || errlog "copy grub boot dir  error !"
		cp $pve_target/boot/efi/EFI/proxmox/grubaa64.efi $pve_target/boot/efi/EFI/BOOT/bootaa64.efi || errlog "copy grub boot file  error !"
	else
		chroot $pve_target grub-install --target x86_64-efi --no-floppy --bootloader-id='proxmox' $newdisk  || errlog "grub install to $newdisk error !"
		cp $pve_target/boot/efi/EFI/proxmox/* $pve_target/boot/efi/EFI/BOOT/  || errlog "copy grub boot dir error !"
		cp $pve_target/boot/efi/EFI/proxmox/grubx64.efi $pve_target/boot/efi/EFI/BOOT/BOOTX64.EFI  || errlog "copy grub boot file error !"
		echo "create bios boot"
		chroot $pve_target grub-install --target=i386-pc --recheck --debug $newdisk  || errlog "grub-pc install error !"
	fi
}

disk_setup(){
	
	dd if=/dev/zero of=$newdisk bs=1M count=16
	echo "create gpt"
	sgdisk -ZG $newdisk
	echo "create bios parttion"
	sgdisk -a1 -n1:34:2047  -t1:EF02  $newdisk  || errlog  "create bios parttion error"
	echo "create efi parttion"
	sgdisk -a1 -n2:1M:+512M -t2:EF00 $newdisk  || errlog   "create efi parttion error"
	mkfs.vfat -F 32 "$newdisk"2
	echo "create root parttion"
	sgdisk -a1 -n3:513M:-1G  $newdisk || errlog   "create root parttion error"
	mkfs.ext4 -F "$newdisk"3
}

newdisk_mount(){
    mkdir -p $pve_target
    mount "$newdisk"3 $pve_target || errlog  "mount new root error"
}

copy_root(){
	mkdir  $pve_target/proc
    rsync -arv --include=sys/*** --include=etc/*** --include=usr/*** --include=var/*** --include=opt/***  --exclude=proc --exclude=mnt/pve/* --exclude=tmp  / $pve_target
	rm  -rf $pve_target/etc/pve $pve_target/var/lib/lxcfs
	mkdir $pve_target/etc/pve $pve_target/var/lib/lxcfs
}

rsync_check(){
	test -f /usr/bin/rsync || errlog "no rsync found"
}

config_check(){
	if [ -z $newdisk ];then
	errlog "disk not defined"
	fi
	if [ ! -b $newdisk ];then
		errlog "$newdisk is not exist"
	fi
	if [ ! -z "$(lsblk -f|grep $newdisk|grep LVM2)" ];then
		echo "Detected lvm filesystem on,abort!"
		echo "please remove it and try again."
	fi
	if [ -z $pve_target ];then
	export pve_target="/tmp/newdisk"
	fi
}

config_check
rsync_check
disk_setup
newdisk_mount
copy_root
prepare_chroot
mount_fstab
grub_install
clean_chroot
