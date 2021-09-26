while getopts v: flag
do
    case "$flag" in
        v) version=${OPTARG}
    esac
done
basepath="$(dirname "$(readlink -f "$0")")"

variables=(
  version
)

for variable in "${variables[@]}"
do
  if [[ -z ${!variable} ]]; then   # indirect expansion here
    echo "ERROR: The param \"${variable}\" is missing.";
    exit 2
  fi
done


# https://cdimage.ubuntu.com/releases/20.04.3/release/ubuntu-20.04.3-preinstalled-server-arm64+raspi.img.xz
image_to_download="https://cdimage.ubuntu.com/releases/${version}/release/ubuntu-${version}-preinstalled-server-arm64+raspi.img.xz"
url_base="https://cdimage.ubuntu.com/releases/${version}/release/"
sha_sum=$( curl $url_base"SHA256SUMS" | grep preinstalled-server-arm64+raspi.img.xz | awk -F " " ' { print $1 } ' )
sdcard_mount="/mnt/sdcard"

if [ $(id | grep 'uid=0(root)' | wc -l) -ne "1" ]
then
    echo "You are not root "
    exit
fi


function umount_sdcard () {
    umount "${sdcard_mount}"
    if [ $( ls -al "${sdcard_mount}" | wc -l ) -eq "3" ]
    then
        echo "Sucessfully unmounted \"${sdcard_mount}\""
        sync
    else
        echo "Could not unmount \"${sdcard_mount}\""
        exit 4
    fi
}

# Download the latest image, using the  --continue "Continue getting a partially-downloaded file"
[[ ! -f ubuntu_image.xz ]] && curl ${image_to_download} -o ubuntu_image.xz

echo "Checking the SHA-1 of the downloaded image matches \"${sha_sum}\""

if [ $( sha256sum ubuntu_image.xz | grep ${sha_sum} | wc -l ) -eq "1" ]
then
    echo "The sha_sums match"
else
    echo "The sha_sums did not match"
    exit 5
fi

if [ ! -d "${sdcard_mount}" ]
then
  mkdir ${sdcard_mount}
fi

# extract
extracted_image="ubuntu-${version}.img"
[[ ! -f ${extracted_image} ]] && xz --decompress -c ubuntu_image.xz > ${extracted_image}

if [ ! -e ${extracted_image} ]
then
    echo "Can't find the image \"${extracted_image}\""
    exit 6
fi

umount_sdcard
echo "Mounting the sdcard boot disk"

loop_base=$( losetup --partscan --find --show "${extracted_image}" )

echo "Running: mount ${loop_base}p1 \"${sdcard_mount}\" "
mount ${loop_base}p1 "${sdcard_mount}"

if [ ! -e "${sdcard_mount}/vmlinuz" ]
then
    echo "Can't find the mounted card\"${sdcard_mount}/vmlinuz\""
    exit 7
fi



cp -v "${basepath}/user-data" "${sdcard_mount}/user-data"

umount_sdcard


new_name="${extracted_image%.*}-configured.img"
cp -v "${extracted_image}" "${new_name}"

losetup --detach ${loop_base}

lsblk

echo ""
echo "Now you can burn the disk using something like:"
echo "      dd bs=4M status=progress if=${new_name} of=/dev/mmcblk????"
echo ""
