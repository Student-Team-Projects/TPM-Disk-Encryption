cd

git clone https://aur.archlinux.org/trousers.git
cd trousers
makepkg -si
cd ..

git clone https://aur.archlinux.org/opencryptoki.git
cd opencryptoki
makepkg -si
cd ..

git clone https://aur.archlinux.org/tpm-tools.git
cd tpm-tools
makepkg -si
cd ..
