apt update && apt upgrade -y && apt install pve-headers-$(uname -r) build-essential software-properties-common make nvtop htop -y

~/NVIDIA-Linux-x86_64-570.169.run --dkms
