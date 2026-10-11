#!/usr/bin/env bash
# TVA rice: configure the official Arch Linux WSL image. Runs as root. Usage: arch-setup.sh <username>
# Safe to re-run.
set -eu
U="${1:?usage: arch-setup.sh <username>}"

echo "==> pacman: colors, parallel downloads, keyring"
sed -i 's/^#Color/Color/; s/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
grep -q '^ILoveCandy' /etc/pacman.conf || sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
pacman-key --init
pacman-key --populate archlinux

echo "==> full system upgrade + packages"
pacman -Syu --noconfirm
pacman -S --noconfirm --needed base-devel git sudo neovim mc btop ripgrep fzf tree jq htop fastfetch curl wget unzip less man-db man-pages openssh which

echo "==> locale"
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo "==> user $U (wheel + sudo)"
id "$U" >/dev/null 2>&1 || useradd -m -G wheel -s /bin/bash "$U"
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel

echo "==> /etc/wsl.conf (systemd, default user, sane Windows-drive permissions)"
[ -f /etc/wsl.conf ] && cp /etc/wsl.conf /etc/wsl.conf.bak
cat > /etc/wsl.conf <<WSLCONF
[boot]
systemd=true

[user]
default=$U

[automount]
options="metadata,umask=022,fmask=011"

[interop]
enabled=true
appendWindowsPath=true
WSLCONF

H="/home/$U"
if ! grep -q '>>> tva-rice >>>' "$H/.bashrc" 2>/dev/null; then
  echo "==> TVA prompt + aliases"
  cat >> "$H/.bashrc" <<'RC'
# >>> tva-rice >>>
__tva_git() { local b; b=$(git symbolic-ref --short HEAD 2>/dev/null) && printf ' (%s)' "$b"; }
# classic Red Hat style prompt: [user@host dir]$
PS1='\[\e[0m\][\[\e[38;5;108m\]\u@\h \[\e[38;5;172m\]\W\[\e[38;5;178m\]$(__tva_git)\[\e[0m\]]\$ '
export EDITOR=nvim
alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias e='nvim'
alias t='btop'
alias fm='mc'
alias open='explorer.exe'
alias files='explorer.exe .'
alias c='clear'
alias update='sudo pacman -Syu'
case $- in *i*) printf '\e[38;5;172mTVA // ARCH LINUX %s // %s\e[0m\n' "$(uname -r)" "$(date '+%a %d %b %Y %H:%M')";; esac
# keep projects in ~ (Linux filesystem), not /mnt/c: it is much faster
# <<< tva-rice <<<
RC
fi

mkdir -p "$H/.config/nvim"
[ -f "$H/.config/nvim/init.lua" ] || cat > "$H/.config/nvim/init.lua" <<'LUA'
vim.o.termguicolors = true
vim.o.number = true
vim.o.cursorline = true
vim.o.mouse = 'a'
vim.cmd.colorscheme('retrobox')
LUA
git config --system core.autocrlf input || true
chown -R "$U:$U" "$H"
echo "==> done"
