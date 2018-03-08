#!/bin/bash

set -e

DEV_PORTNUM=2
MEMSIZE="2GB"

CROSS_COMPILE="arm-eabi-"

KERNEL_IMG=${KERNEL_DIR}/arch/arm/boot/zImage
DTB_IMG=${KERNEL_DIR}/arch/arm/boot/dts/s5p4418-raptor-rev00.dtb

UBOOT_LOAD_ADDR=0x40007800

if [ "${BUILD_ALL}" == "true" ] || [ "${BUILD_BL1}" == "true" ]; then
	build_bl1_s5p4418 ${BL1_DIR}/bl1-${TARGET_SOC} s5p4418 avn ${DEV_PORTNUM}
fi

if [ "${BUILD_ALL}" == "true" ] || [ "${BUILD_UBOOT}" == "true" ]; then
	build_uboot ${UBOOT_DIR} ${TARGET_SOC} ${BOARD_NAME} ${CROSS_COMPILE}
	gen_third ${TARGET_SOC} ${UBOOT_DIR}/u-boot.bin \
		0x43c00000 0x43c00000 ${TOP}/device/nexell/secure/bootloader.img
fi

if [ "${BUILD_ALL}" == "true" ] || [ "${BUILD_SECURE}" == "true" ]; then
	pos=0
	file_size=0

	build_bl2_s5p4418 ${TOP}/device/nexell/secure/bl2-s5p4418
	build_armv7_dispatcher ${TOP}/device/nexell/secure/armv7-dispatcher

	gen_third ${TARGET_SOC} ${TOP}/device/nexell/secure/bl2-s5p4418/out/pyrope-bl2.bin \
		0xb0fe0000 0xb0fe0400 ${TOP}/device/nexell/secure/loader-emmc.img \
		"-m 0x40200 -b 3 -p ${DEV_PORTNUM} -m 0x1E0200 -b 3 -p ${DEV_PORTNUM} -m 0x60200 -b 3 -p ${DEV_PORTNUM}"
	gen_third ${TARGET_SOC} ${TOP}/device/nexell/secure/armv7-dispatcher/out/armv7_dispatcher.bin \
		0xffff0200 0xffff0200 ${TOP}/device/nexell/secure/bl_mon.img \
		"-m 0x40200 -b 3 -p ${DEV_PORTNUM} -m 0x1E0200 -b 3 -p ${DEV_PORTNUM} -m 0x60200 -b 3 -p ${DEV_PORTNUM}"

	file_size=35840
	dd if=${TOP}/device/nexell/secure/loader-emmc.img of=${TOP}/device/nexell/secure/fip-loader-usb.img seek=0 bs=1
	let pos=pos+file_size
	file_size=28672
	dd if=${TOP}/device/nexell/secure/bl_mon.img of=${TOP}/device/nexell/secure/fip-loader-usb.img seek=${pos} bs=1
	let pos=pos+file_size
	dd if=${TOP}/device/nexell/secure/bootloader.img of=${TOP}/device/nexell/secure/fip-loader-usb.img seek=${pos} bs=1
fi

if [ "${BUILD_ALL}" == "true" ] || [ "${BUILD_KERNEL}" == "true" ]; then
	build_kernel ${KERNEL_DIR} ${TARGET_SOC} ${BOARD_NAME} s5p4418_raptor_nougat_defconfig ${CROSS_COMPILE}
	test -d ${OUT_DIR} && \
		cp ${KERNEL_IMG} ${OUT_DIR}/kernel && \
		cp ${DTB_IMG} ${OUT_DIR}/2ndbootloader
fi

if [ "${BUILD_ALL}" == "true" ] || [ "${BUILD_MODULE}" == "true" ]; then
	build_module ${KERNEL_DIR} ${TARGET_SOC} ${CROSS_COMPILE}
fi

if [ "${BUILD_ALL}" == "true" ] || [ "${BUILD_ANDROID}" == "true" ]; then
	rm -rf ${OUT_DIR}/system
	rm -rf ${OUT_DIR}/root
	rm -rf ${OUT_DIR}/data
	generate_key ${BOARD_NAME}
	test -f ${DEVICE_DIR}/domain.te && cp ${DEVICE_DIR}/domain.te ${TOP}/system/sepolicy
	test -f ${DEVICE_DIR}/app.te && cp ${DEVICE_DIR}/app.te ${TOP}/system/sepolicy
	build_android ${TARGET_SOC} ${BOARD_NAME} ${BUILD_TAG}
fi

# u-boot envs
echo "make u-boot envs"
if [ -f ${UBOOT_DIR}/u-boot.bin ]; then
	UBOOT_BOOTCMD=$(make_uboot_bootcmd \
		${DEVICE_DIR}/partmap.txt \
		${UBOOT_LOAD_ADDR} \
		2048 \
		${KERNEL_IMG} \
		${DTB_IMG} \
		${OUT_DIR}/ramdisk.img \
		"boot:emmc")

	UBOOT_RECOVERYCMD="ext4load mmc 0:6 0x49000000 recovery.dtb; ext4load mmc 0:6 0x40008000 recovery.kernel; ext4load mmc 0:6 0x48000000 ramdisk-recovery.img; bootz 40008000 0x48000000:27e800 0x49000000"

	UBOOT_BOOTARGS="console=ttyAMA3,115200n8 loglevel=7 printk.time=1 androidboot.hardware=raptor androidboot.console=ttyAMA3 androidboot.serialno=0123456789ABCDEF quiet"

	SPLASH_SOURCE="mmc"
	SPLASH_OFFSET="0x2e4200"

	echo "UBOOT_BOOTCMD ==> ${UBOOT_BOOTCMD}"
	echo "UBOOT_RECOVERYCMD ==> ${UBOOT_RECOVERYCMD}"

	pushd `pwd`
	cd ${UBOOT_DIR}
	build_uboot_env_param ${CROSS_COMPILE} "${UBOOT_BOOTCMD}" "${UBOOT_BOOTARGS}" "${SPLASH_SOURCE}" "${SPLASH_OFFSET}" "${UBOOT_RECOVERYCMD}"
	popd

fi

# make bootloader
echo "make bootloader"
bl1=${BL1_DIR}/bl1-${TARGET_SOC}/out/bl1-emmcboot.bin
loader=${TOP}/device/nexell/secure/loader-emmc.img
secure=${TOP}/device/nexell/secure/bl_mon.img
nonsecure=${TOP}/device/nexell/secure/bootloader.img
param=${UBOOT_DIR}/params.bin
boot_logo=${DEVICE_DIR}/logo.bmp
out_file=${DEVICE_DIR}/bootloader

if [ -f ${bl1} ] && [ -f ${loader} ] && [ -f ${secure} ] && [ -f ${nonsecure} ] && [ -f ${param} ] && [ -f ${boot_logo} ]; then
	BOOTLOADER_PARTITION_SIZE=$(get_partition_size ${DEVICE_DIR}/partmap.txt bootloader)
	make_bootloader \
		${BOOTLOADER_PARTITION_SIZE} \
		${bl1} \
		65536 \
		${loader} \
		262144 \
		${secure} \
		1966080 \
		${nonsecure} \
		3014656 \
		${param} \
		3031040 \
		${boot_logo} \
		${out_file}

	test -d ${OUT_DIR} && cp ${DEVICE_DIR}/bootloader ${OUT_DIR}
fi

if [ "${BUILD_DIST}" == "true" ]; then
	build_dist ${TARGET_SOC} ${BOARD_NAME} ${BUILD_TAG}
fi

if [ "${BUILD_KERNEL}" == "true" ]; then
	test -f ${OUT_DIR}/ramdisk.img && \
		make_android_bootimg \
			${KERNEL_IMG} \
			${DTB_IMG} \
			${OUT_DIR}/ramdisk.img \
			${OUT_DIR}/boot.img \
			2048 \
			"buildvariant=${BUILD_TAG}"
fi

post_process ${TARGET_SOC} \
	${DEVICE_DIR}/partmap.txt \
	${RESULT_DIR} \
	${BL1_DIR}/bl1-${TARGET_SOC}/out \
	${TOP}/device/nexell/secure \
	${UBOOT_DIR} \
	${KERNEL_DIR}/arch/arm/boot \
	${KERNEL_DIR}/arch/arm/boot/dts \
	67108864 \
	${OUT_DIR} \
	avn \
	${DEVICE_DIR}/logo.bmp

make_ext4_recovery_image \
	${KERNEL_DIR}/arch/arm/boot/zImage \
	${KERNEL_DIR}/arch/arm/boot/dts/s5p4418-raptor-rev00.dtb \
	${OUT_DIR}/ramdisk-recovery.img \
	67108864 \
	${RESULT_DIR}

ADDRESS=0x93c00000
if [ "${MEMSIZE}" == "2GB" ]; then
	ADDRESS=0x63c00000
elif [ "${MEMSIZE}" == "1GB" ]; then
	ADDRESS=0x83c00000
fi
gen_boot_usb_script_4418 slsiap ${ADDRESS} ${RESULT_DIR}

make_build_info ${RESULT_DIR}
