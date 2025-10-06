#!/usr/bin/env bash
set -euo pipefail

# Seed user home from persistent /coder/home when needed.
# During image build we populated /coder/home with things like antidote,
# fnm aliases, and oh-my-posh themes. The user's $HOME is often a mounted
# volume at runtime and initially empty; copy files from /coder/home into
# $HOME if they don't already exist.
seed_from_persistent() {
  src_root="/coder/home"
  if [ ! -d "$src_root" ]; then
    return
  fi
  echo "Seeding user home from $src_root"
  mkdir -p "$HOME"
  # Helper to rsync a source subdir into target (ignore existing files)
  rsync_subdir() {
    local s="$1" t="$2"
    if [ -d "$s" ]; then
      mkdir -p "$t"
      if [ "$(id -u)" -eq 0 ]; then
        # If running as root, prefer to chown copied files to the target user
        target_user="${SUDO_USER:-$(logname 2>/dev/null || echo embold)}"
        echo "Copying $s -> $t (chown -> $target_user)"
        rsync -aH --ignore-existing --chmod=Du=rwx,Dg=rx,Do=rx,Fu=rw,Fg=r,Fo=r --chown="$target_user:$target_user" "$s/" "$t/" || true
      else
        echo "Copying $s -> $t"
        rsync -aH --ignore-existing "$s/" "$t/" || true
      fi
    fi
  }

  rsync_subdir "$src_root/.local" "$HOME/.local"
  rsync_subdir "$src_root/.fnm" "$HOME/.fnm"
  rsync_subdir "$src_root/.cache/oh-my-posh/themes" "$HOME/.cache/oh-my-posh/themes"
  rsync_subdir "$src_root/.config/antidote" "$HOME/.config/antidote"

  # Ensure ownership and basic perms are correct for HOME
  if [ "$(id -u)" -eq 0 ]; then
    target_user="${SUDO_USER:-$(logname 2>/dev/null || echo embold)}"
    target_home="$(eval echo ~${target_user})"
    chown -R "$target_user:$target_user" "$target_home" || true
  fi
}

# Ensure image-provided gems for the current Ruby version are visible to the
# user by creating a small profile snippet under $HOME/.profile.d that adds
# /coder/gems/ruby/<ver> to GEM_PATH and PATH. This avoids copying large gem
# trees while ensuring interactive shells pick them up.
seed_gems_env() {
  # Detect the ruby version if ruby is available
  if command -v ruby >/dev/null 2>&1; then
    ruby_ver=$(ruby -e 'print RUBY_VERSION' 2>/dev/null || true)
  else
    ruby_ver=""
  fi

  if [ -z "$ruby_ver" ]; then
    return
  fi

  coder_gems_dir="/coder/gems/ruby/$ruby_ver"
  if [ ! -d "$coder_gems_dir" ]; then
    return
  fi

  profile_dir="$HOME/.profile.d"
  mkdir -p "$profile_dir"
  snippet="$profile_dir/embold-image-gems.sh"
  if [ -f "$snippet" ]; then
    return
  fi

  cat > "$snippet" <<'EOF'
# embold: expose image-provided gems for this Ruby version
if [ -d "/coder/gems/ruby/REPLACE_RUBY_VER" ]; then
  export GEM_PATH="$GEM_PATH:/coder/gems/ruby/REPLACE_RUBY_VER"
  export PATH="$PATH:/coder/gems/ruby/REPLACE_RUBY_VER/bin"
fi
EOF

  # Replace placeholder with detected ruby_ver
  sed -i "s/REPLACE_RUBY_VER/$ruby_ver/g" "$snippet" || true

  # Ensure snippet is readable and owned by the user when running as root
  if [ "$(id -u)" -eq 0 ]; then
    target_user="${SUDO_USER:-$(logname 2>/dev/null || echo embold)}"
    chown "$target_user:$target_user" "$snippet" || true
    chmod 0644 "$snippet" || true
  else
    chmod 0644 "$snippet" || true
  fi
}

# Run seeding early so later initialization (dotfiles, gems) sees provided files
seed_from_persistent
seed_gems_env
