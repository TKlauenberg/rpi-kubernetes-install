# Echo usage if something isn't right.
usage() {
    echo "Usage: $0 [-v <version>] [-d <device>]" 1>&2; exit 1;
}

while getopts ":v:d:" o; do
    case "${o}" in
        v)
            version=${OPTARG}
            ;;
        d)
            echo "testdevice"
            device=${OPTARG}
            ;;
        :)
            echo "ERROR: Option -$OPTARG requires an argument"
            usage
            ;;
        \?)
            echo "ERROR: Invalid option -$OPTARG"
            usage
            ;;
    esac
done
shift $((OPTIND-1))
basepath="$(dirname "$(readlink -f "$0")")"

variables=(
    version
    device
)

for variable in "${variables[@]}"
do
    if [[ -z ${!variable} ]]; then   # indirect expansion here
        echo "ERROR: The param \"${variable}\" is missing.";
        usage
        exit 1
    fi
done

image_to_download="https://dl-cdn.alpinelinux.org/alpine/v${version}/releases/aarch64/alpine-rpi-${version}.0-aarch64.tar.gz"
sdcard_mount="/mnt/sdcard"
echo "${image_to_download}"

if [ $(id | grep 'uid=0(root)' | wc -l) -ne "1" ]
then
    echo "You are not root "
    exit 3
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

# TODO check if file in folder matches the file which should be downloaded
[[ ! -f $basepath/alpine-base.tar.gz ]] && curl ${image_to_download} -o $basepath/alpine-base.tar.gz


# TODO add later
# echo "Checking the SHA-1 of the downloaded image matches \"${sha_sum}\""

# if [ $( sha256sum ubuntu_image.xz | grep ${sha_sum} | wc -l ) -eq "1" ]
# then
#     echo "The sha_sums match"
# else
#     echo "The sha_sums did not match"
#     exit 5
# fi

if [ ! -d "${sdcard_mount}" ]
then
    mkdir ${sdcard_mount}
fi

echo "Format SD-Card"

if [ ! -e "${device}" ]
then
    echo "Can't find the device \"${device}\""
    exit 6
fi

sfdisk $device < $basepath/partition-tablesroot

mkdosfs -F 32 ${device}1
mkfs.ext4 -F ${device}2

echo "Running: mount ${device}1 \"${sdcard_mount}\" "
mount ${device}1 "${sdcard_mount}"

# if [ ! -e "${sdcard_mount}/vmlinuz" ]
# then
#     echo "Can't find the mounted card\"${sdcard_mount}/vmlinuz\""
#     exit 7
# fi

tar -xf $basepath/alpine-base.tar.gz -C "${sdcard_mount}"
cp -v "${basepath}/headless.tar.gz" "${sdcard_mount}/localhost.apkovl.tar.gz"

umount_sdcard
echo "SD-Card successfully prepared"
