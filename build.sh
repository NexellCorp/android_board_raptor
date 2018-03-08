#!/bin/bash

set -e

TOP=`pwd`

source ${TOP}/device/nexell/tools/common.sh
source ${TOP}/device/nexell/tools/dir.sh
source ${TOP}/device/nexell/tools/make_build_info.sh
source ${TOP}/device/nexell/tools/revert_patches.sh

parse_args $@
print_args
setup_toolchain
export_work_dir

# revert_common ${TOP}/device/nexell/raptor/patch
# patch_common ${TOP}/device/nexell/raptor/patch

DEVICE_DIR=${TOP}/device/nexell/${BOARD_NAME}
OUT_DIR=${TOP}/out/target/product/${BOARD_NAME}

echo "TARGET_SOC --> ${TARGET_SOC}"
if [ "${TARGET_SOC}" == "s5p6818" ]; then
	cp ${DEVICE_DIR}/TargetArm64Config.mk ${DEVICE_DIR}/BoardConfig.mk
	cp ${DEVICE_DIR}/aosp_raptor_64.mk ${DEVICE_DIR}/aosp_raptor.mk
	source ${DEVICE_DIR}/build_s5p6818.sh $@
else
	cp ${DEVICE_DIR}/TargetArmConfig.mk ${DEVICE_DIR}/BoardConfig.mk
	cp ${DEVICE_DIR}/aosp_raptor_32.mk ${DEVICE_DIR}/aosp_raptor.mk
	source ${DEVICE_DIR}/build_s5p4418.sh $@
fi

exit
