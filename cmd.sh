petalinux-config --get-hw-description=../hdf/ov5640_quad.sdk
petalinux-build
petalinux-package --boot --fsbl ./images/linux/zynq_fsbl.elf --fpga --u-boot --force
scp images/linux/BOOT.BIN  images/linux/image.ub images/linux/system.dtb root@192.168.1.88:/mnt/boot/
scp BOOT.BIN  image.ub root@192.168.1.88:/mnt/boot/

load mmc 0 0x100000 system.bit
fpga loadb 0 0x100000 976365

env default -a 
setenv bitstream_load_address 0x100000
setenv bitstream_image system.bit 
setenv bitstream_size 0x300000 
setenv kernel_img zImage 
setenv dtbnetstart 0x2000000 
setenv netstart 0x2080000 
setenv default_bootcmd 'if mmcinfo; then run uenvboot; echo Copying Linux from SD to RAM... &&  load mmc 0 ${bitstream_load_address} ${bitstream_image} && fpga loadb 0 ${bitstream_load_address} ${bitstream_size} && run cp_kernel2ram && run cp_dtb2ram && bootz ${netstart} - ${dtbnetstart}; fi' 

