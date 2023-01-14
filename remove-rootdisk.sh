#!/bin/bash
#first_define_your_new_disk

newdisk="/dev/sdb"
pve_target="/tmp/newdisk"

mount_fstab(){
    echo > $pve_target/etc/fstab
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
	umount -l $pve_target/proc
	umount -l $pve_target/sys
    umount -l $pve_target/dev/pts
	umount -l $pve_target/dev
    chroot $pve_target umount /run
    umount $pve_target/mnt/hostrun
	umount -l $pve_target/boot/efi/
	umount -l $pve_target
}

grub_install(){
	echo "create efi boot"
	mkdir $pve_target/boot/efi 
	chroot $pve_target mount "$newdisk"2 /boot/efi
	chroot $pve_target update-grub
	mkdir $pve_target/boot/efi/EFI/BOOT/ -p
	chroot $pve_target grub-install --target x86_64-efi --no-floppy --bootloader-id='proxmox' $newdisk
	cp $pve_target/boot/efi/EFI/proxmox/grubx64.efi $pve_target/boot/efi/EFI/BOOT/BOOTX64.EFI 
	echo "create bios boot"
	chroot $pve_target grub-install --target=i386-pc --recheck --debug $newdisk
}


disk_setup(){
	if [ ! -b $newdisk ];then
		echo "$newdisk is not exist"
		echo "exit!"
		exit 0;
	fi	
	#check disk whether exist
	dd if=/dev/zero of=$newdisk bs=1M count=16
	echo "create gpt"
	sgdisk -Z $newdisk

	echo "create bios parttion"
	sgdisk -a1 -n1:34:2047  -t1:EF02  $newdisk

	echo "create efi parttion"
	sgdisk -a1 -n2:1M:+512M -t2:EF00 $newdisk
	mkfs.vfat -F 32 "$newdisk"2

	echo "create root parttion"
	sgdisk -a1 -n3:513M:-1G  $newdisk
	mkfs.ext4 -F "$newdisk"3
}

newdisk_mount{
    mkdir -p $pve_target
    mount "$newdisk"3 $pve_target
}

copy_root{
    cp -ar / $pve_target
}

disk_setup
newdisk_mount
copy_root
prepare_chroot
mount_fstab
grub_install
clean_chroot