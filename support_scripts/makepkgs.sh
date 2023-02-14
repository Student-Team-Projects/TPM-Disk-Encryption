cd

echo "Installing trousers package"
git clone https://aur.archlinux.org/trousers.git
cd trousers
makepkg -si
cd ..

echo "Installing opencryptoki package"
git clone https://aur.archlinux.org/opencryptoki.git
cd opencryptoki
makepkg -si
cd ..

echo "Installing tpm-tools package"
git clone https://aur.archlinux.org/tpm-tools.git
cd tpm-tools
makepkg -si
cd ..
