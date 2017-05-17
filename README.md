# GPU-Passthrough-Manjaro-Linux-to-Windows10

### Setup the Graphics card:

edit /etc/default/grub
```
GRUB_CMDLINE_LINUX_DEFAULT="resume=UUID=6771936b-06b6-493c-b655-6f60122f5228 **intel_iommu=on**"
```
then
```
sudo grub-mkconfig -o /boot/grub/grub.cfg
```
reboot
then,
```
lspci -nnk
```
check
```
02:00.0 VGA compatible controller [0300]: NVIDIA Corporation GM200 [GeForce GTX 980 Ti] [10de:17c8] (rev a1)
Subsystem: ASUSTeK Computer Inc. Device [1043:8548]
Kernel driver in use: nvidia
Kernel modules: nouveau, nvidia
02:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:0fb0] (rev a1)
Subsystem: ASUSTeK Computer Inc. Device [1043:8548]
Kernel driver in use: snd_hda_in
```
then
``` 
ls -lha /sys/bus/pci/devices/0000\:02\:00.0/iommu_group/devices/
```
make sure ioummo groups are good.
then
edit  grub.cfg at /etc/default/grub
```
GRUB_CMDLINE_LINUX_DEFAULT="resume=UUID=6771936b-06b6-493c-b655-6f60122f5228 **pcie_acs_override=downstream** intel_iommu=on"
```
then
```
sudo grub-mkconfig -o /boot/grub/grub.cfg
```
edit /etc/mkinitcpio.conf
``` 
MODULES="pci-stub"
```
then
```
sudo mkinitcpio -p linux
```
reboot
then
edit /etc/default/grub
```
GRUB_CMDLINE_LINUX_DEFAULT="resume=UUID=6771936b-06b6-493c-b655-6f60122f5228 pcie_acs_override=downstream intel_iommu=on **pci-stub.ids=whatever lspci -nnk says the id is: should be like 10de:17c8,10de:0fb0"**"
```
reboot
then
```
lspci -nnk
```
check
> Kernel driver in use: pci-stub

### Setup Qemu and scripts
sudo pacman -S qemu rpmextract
``` [kemmler@arch ovmf]$ ls edk2.git-ovmf-x64-0-20150916.b1214.g2f667c5.noarch.rpm 
[kemmler@arch ovmf]$ rpmextract.sh edk2.git-ovmf-x64-0-20150916.b1214.g2f667c5.noarch.rpm 
[kemmler@arch ovmf]$ ls edk2.git-ovmf-x64-0-20150916.b1214.g2f667c5.noarch.rpm usr 
[kemmler@arch ovmf]$ sudo cp -R usr/share/* /usr/share/
[kemmler@arch ovmf]$ ls /usr/share/edk2.git/ovmf-x64/ 
OVMF_CODE-pure-efi.fd OVMF_CODE-with-csm.fd OVMF-pure-efi.fd OVMF_VARS-pure-efi.fd OVMF_VARS-with-csm.fd OVMF-with-csm.fd UefiShell.iso ```
then
make a script called vfio-bind in /usr/bin w/ chmod +x
```
#!/bin/bash

modprobe vfio-pci

for dev in "$@"; do
vendor=$(cat /sys/bus/pci/devices/$dev/vendor)
device=$(cat /sys/bus/pci/devices/$dev/device)
if [ -e /sys/bus/pci/devices/$dev/driver ]; then
echo $dev > /sys/bus/pci/devices/$dev/driver/unbind
fi
echo $vendor $device > /sys/bus/pci/drivers/vfio-pci/new_id
done
```
then bind the gpu (lspci):
```
sudo vfio-bind 0000:01:00.0 0000:01:00.1
```
verify:
```
lspci -nnk
```
> Kernel driver in use: vfio-pci
then 
```
qemu-img create -f qcow2 -o preallocation=metadata,compat=1.1,lazy_refcounts=on win.img 120G
```
then make a script called windows10vm in /usr/bin w/ chmod +x
```
#!/bin/bash

cp /usr/share/edk2.git/ovmf-x64/OVMF_VARS-pure-efi.fd /tmp/my_vars.fd
qemu-system-x86_64 \
-enable-kvm \
-m 2048 \
-cpu host,kvm=off \
-vga none \
-usb -usbdevice host:1b1c:1b09 \
-device vfio-pci,host=01:00.0,multifunction=on \
-device vfio-pci,host=01:00.1 \
-drive if=pflash,format=raw,readonly,file=/usr/share/edk2.git/ovmf-x64/OVMF_CODE-pure-efi.fd \
-drive if=pflash,format=raw,file=/tmp/my_vars.fd \
-device virtio-scsi-pci,id=scsi \
-drive file=/home/kemmler/kvm/win10.iso,id=isocd,format=raw,if=none -device scsi-cd,drive=isocd \
-drive file=/home/kemmler/kvm/win.img,id=disk,format=qcow2,if=none,cache=writeback -device scsi-hd,drive=disk \
-drive file=/home/kemmler/kvm/virt.iso,id=virtiocd,if=none,format=raw -device ide-cd,bus=ide.1,drive=virtiocd
```

### 
