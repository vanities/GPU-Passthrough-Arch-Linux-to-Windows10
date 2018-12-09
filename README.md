# GPU Passthrough from Arch Linux

#### Combines these sources:
1. https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF

2. https://passthroughpo.st/quick-dirty-arch-passthrough-guide/

3. https://medium.com/@dubistkomisch/gaming-on-arch-linux-and-windows-10-with-vfio-iommu-gpu-passthrough-7c395dde5c2

4. https://pastebin.com/wetAhhVX

#### When to do this:

When you want to play windows 10 video games from your arch box. My text editor is nvim, replace it with whatever your text editor is (nano, vim, emacs)

#### Installation:

Most of this stuff is in the archlinux guide at the top, read more of that if any of this is confusing or something goes wrong.

## PCI passthrough via OVMF (GPU)

### Initialization

1. Make sure that you have already enabled IOMMU via AMD-Vi or Intel Vt-d in your motherboard's BIOS 
HIT F10 or del or whatever the key is for your motherboard during bios initialization at beginning of startup, enable either VT-d if you have an Intel CPU or AMD-vi if you have an AMD CPU

2. edit `/etc/default/grub` and add intel_iommu=on to GRUB_CMDLINE_LINUX_DEFAULT

`$ sudo nvim /etc/default/grub`

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
```

3. re-configure your grub:

`$ sudo grub-mkconfig -o /boot/grub/grub.cfg`

4. reboot

`$ sudo reboot now`


### Isolating the GPU

One of the first things you will want to do is isolate your GPU. The goal of this is to prevent the Linux kernel from loading drivers that would take control of the GPU. Because of this, it is necessary to have two GPUs installed and functional within your system. One will be used for interacting with your Linux host (just like normal), and the other will be passed-through to your Windows guest. In the past, this had to be achieved through using a driver called pci-stub. While it is still possible to do so, it is older and holds no advantage over its successor –vfio-pci.

1. find the device ID of the GPU that will be passed through by running lscpi

`$ lspci -nn`

and look through the given output until you find your desired GPU, they're **bold** in this case:

>01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GM204 [GeForce GTX 980] **[10de:13c0]** (rev a1)
>01:00.1 Audio device [0403]: NVIDIA Corporation GM204 High Definition Audio Controller **[10de:0fbb]** (rev a1)


### Configuring vfio-pci and Regenerating your Initramfs

Next, we need to instruct vfio-pci to target the device in question through the ID numbers gathered above.

1. edit `/etc/modprobe.d/vfio.conffile` and adding the following line with **your ids from the last step above**:

```
options vfio-pci ids=10de:13c0,10de:0fbb
```

Next, we will need to ensure that vfio-pciis loaded before other graphics drivers. 

2. edit `/etc/mkinitcpio.conf`. At the very top of your file you should see a section titled MODULES. Towards the bottom of this section you should see the uncommented line: MODULES= . Add the in the following order before any other drivers (nouveau, radeon, nvidia, etc) which may be listed: vfio vfio_iommu_type1 vfio_pci vfio_virqfd. A sample line may look like the following:

```
MODULES="vfio vfio_iommu_type1 vfio_pci vfio_virqfd nouveau"
```

In the same file, also add modconf to the HOOKSline:

```
HOOKS="modconf"
```

3. rebuild initramfs.

`mkinitcpio -g /boot/linux-custom.img`

4. reboot
`$ sudo reboot now`

### Checking whether it worked

1. run
`$ lspci -nnk`

Find your GPU and ensure that under “Kernel driver in use:” vfio-pci is displayed:


```
1:00.0 VGA compatible controller [0300]: NVIDIA Corporation GM204 [GeForce GTX 980] [10de:13c0] (rev a1)
	Subsystem: Micro-Star International Co., Ltd. [MSI] GM204 [GeForce GTX 980] [1462:3177]
	Kernel driver in use: vfio-pci
	Kernel modules: nouveau
01:00.1 Audio device [0403]: NVIDIA Corporation GM204 High Definition Audio Controller [10de:0fbb] (rev a1)
	Subsystem: Micro-Star International Co., Ltd. [MSI] GM204 High Definition Audio Controller [1462:3177]
	Kernel driver in use: vfio-pci
	Kernel modules: snd_hda_intel
```

2. ???
3. profit?

 

### Configuring OVMF and Running libvirt

1. download libvirt, virt-manager, ovmf, and qemu (these are all available in the AUR). OVMF is an open-source UEFI firmware designed for KVM and QEMU virtual machines. ovmf may be omitted if your hardware does not support it, or if you would prefer to use SeaBIOS. However, configuring it is very simple and typically worth the effort.

`sudo pacman -S libvirt virt-manager ovmf qemu`

2. edit `/etc/libvirt/qemu.conf` and add the path to your OVMF firmware image:

```
nvram = ["/usr/share/ovmf/ovmf_code_x64.bin:/usr/share/ovmf/ovmf_vars_x64.bin"]
```

3. start and enable both libvirtd and its logger, virtlogd.socket in systemd if you use a different init system, substitute it's commands in for systmectl start

```
$ sudo systemctl start libvirtd.service 
$ sudo systemctl start virtlogd.socket
$ sudo systemctl enable libvirtd.service
$ sudo systemctl enable virtlogd.socket
```

With libvirt running, and your GPU bound, you are now prepared to open up virt-manager and begin configuring your virtual machine. 

### virt-manager, a GUI for managing virtual machines

**virt-manager** has a fairly comprehensive and intuitive GUI, so you should have little trouble getting your Windows guest up and running. 

1. download virt-manager

`$ sudo pacman -S virt-manager`

2. add yourself to the libvirt group (replace vanities with your username)

`$ sudo usermod -a -G libvirt vanities`

3. launch virt-manager

`$ virt-manager`

4. add your own vm with a windows *.iso* file

5. setup your GPU, navigate to the “Add Hardware” section and select both the GPU and its sound device that was isolated previously in the **PCI** tab

6. test to see if it works

## Performance Tuning

### CPU pinnging
soon..
