while getopts d: flag
do
    case "$flag" in
        d) device=${OPTARG}
    esac
done
basepath="$(dirname "$(readlink -f "$0")")"

# wipe filesystem
for n in $device?
do
    echo $n
    sudo umount $n
done
sudo wipefs -af $device


# create new base structure only with system partition
sudo parted $device mklabel msdos
sudo parted $device mkpart primary 1 2g
sudo parted $device set 1 boot on
sudo parted $device set 1 lba on
sudo mkfs.vfat "${device}1"

ALPINE_BASE_IMAGE="https://dl-cdn.alpinelinux.org/alpine/v3.14/releases/aarch64/alpine-rpi-3.14.0-aarch64.tar.gz"


[[ ! -f $basepath/static/alpine-rpi.tar.gz ]] && curl -o $basepath/static/alpine-rpi.tar.gz $ALPINE_BASE_IMAGE || echo "Alpine baseimg already exists"
[[ ! -f $basepath/static/temp ]] && mkdir -p $basepath/static/temp
sudo mount "${device}1" $basepath/static/temp
sudo tar -xvpzf $basepath/static/alpine-rpi.tar.gz -C $basepath/static/temp --no-same-owner
# todo do more config?

sudo umount "${device}1"