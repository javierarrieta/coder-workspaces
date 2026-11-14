{ pkgs }:
let
  # tests fail in the container build env (indent/cd/path check scripts)
  fish = pkgs.fish.overrideAttrs (old: {
    doCheck = false;
  });

  # nixpkgs-unstable (this flake's input) ships bun 1.3.13; bun 1.4.0 is newer.
  # Prefer the official prebuilt binary over rebuilding from source. NOTE: the
  # release-asset download can be non-deterministic across environments (a
  # fixed-output hash is therefore environment-specific). If a build reports a
  # `hash mismatch ... got: sha256-…`, paste that value in here and rebuild.
  bun = pkgs.stdenvNoCC.mkDerivation {
    name = "bun";
    dontUnpack = true;
    buildInputs = [ pkgs.unzip ];
    installPhase = ''
      mkdir -p $out/bin
      unzip -j "${pkgs.fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.0/bun-linux-x64.zip";
        hash = "sha256-LQP7X7g6yLVnrKCigbLOGhoZ1Ij1bClo2Iw/Jekv5FI=";
      }}" "bun-linux-x64/bun"
      chmod +x bun
      mv bun $out/bin/bun
    '';
  };
in
pkgs.dockerTools.buildImage {
  name = "coder-workspaces-nix";
  tag = "pinned";
  copyToRoot = pkgs.buildEnv {
    name = "coder-workspace-root";
    paths = with pkgs; [
      bash
      bashInteractive
      zsh
      coreutils
      git
      curl
      cacert
      gcc
      gnumake
      binutils
      findutils
      gnugrep
      gawk
      gnused
      diffutils
      which
      gnutar
      gzip
      iputils
      iproute2
      net-tools
      openssh
      rsync
      sudo
      python312
      ripgrep
      fd
      jq
      htop
      ncdu
      less
      strace
      wget
      unzip
      xz
      file
      tree
      nix
      home-manager
      fish
      rustc
      cargo
      rustfmt
      clippy
      uv
      bun
      gh
      git-lfs
      direnv
      zoxide
      fzf
      bat
      eza
      tmux
      # Terminal workspace manager for AI coding agents (herdr.dev). Ships in
      # nixos-unstable (0.9.1 == latest upstream tag) and is substituted from
      # cache.nixos.org, so no local prebuilt override is needed.
      herdr
      procps
      util-linux
      psmisc
      patch
      man-db
      bc
      ed
      neovim
      vim
      sops
      age
      scala
      sbt
      postgresql
      sqlite
      nixd
      nixfmt-tree
      # Nix dev tooling: RFC 166 formatter, linters, build monitor, cache push,
      # closure diff.
      nixfmt-rfc-style
      statix
      deadnix
      nix-output-monitor
      cachix
      nvd
      go
      skopeo
      kubectl
      # Rootless containers *inside* the workspace (podman run postgres:18 for a
      # test database, for example). nixpkgs' podman wrapper already carries
      # conmon, crun, netavark, aardvark-dns and passt, so no extra network
      # package is needed. `shadow` supplies newuidmap/newgidmap, which the
      # runAsRoot block below re-installs setuid — the store copy is 0755 and
      # rootless podman cannot build a multi-id user namespace without it.
      podman
      shadow
      # Shell prompt
      starship
      btop
      difftastic
      dyff
      fastfetch
      kubernetes-helm
      scala-cli
      kubectx
      k9s
      opentofu
      # python312Packages.pipenv does not exist on this nixpkgs rev;
      # top-level pipenv tracks the default python.
      pipenv
      python312Packages.virtualenv
      python312Packages.pylint
      python312Packages.oci
      python312Packages.huggingface-hub
      nodejs_24
      codex
      # Git UX
      lazygit
      delta
      # Shell: synced history
      atuin
      # Task runner + file watchers
      just
      watchexec
      entr
      # Network / HTTP client tools
      xh
      httpie
      socat
      mtr
      # Sys monitoring / disk usage
      duf
      dust
      procs
      # Misc dev CLI
      yq
      fx
      hyperfine
      tokei
      tldr
      glab
      helix
    ];
    # /share is linked so packages' shipped shell completions (herdr's fish/zsh/bash
    # completions, etc.) and other share/ data are reachable in the image.
    pathsToLink = [
      "/bin"
      "/etc"
      "/share"
    ];
  };
  runAsRoot = ''
    ${pkgs.dockerTools.shadowSetup}
    groupadd --gid 1000 coder
    useradd --uid 1000 --gid 1000 --create-home --home-dir /home/coder --shell /bin/bash coder
    ln -sfn ${pkgs.bash}/bin/bash /bin/sh
    echo /bin/bash >> /etc/shells
    echo /bin/fish >> /etc/shells
    cat > /etc/bashrc <<'EOF'
    # Hand off interactive TTY sessions to fish; VS Code Remote-SSH spawns a
    # non-interactive piped-stdin shell and must stay on bash. Note that
    # [[ -o interactive ]] is always false (no such option); use $- like this.
    if [[ $- == *i* ]] && [[ -t 0 ]] && command -v fish >/dev/null 2>&1; then
      exec fish
    fi
    EOF
    cat > /etc/profile <<'EOF'
    # Login shells source this file. Hand off interactive TTY login sessions to
    # fish; non-interactive login shell runs (VS Code Remote-SSH piped bootstrap)
    # must stay on bash.
    if [[ $- == *i* ]] && [[ -t 0 ]] && command -v fish >/dev/null 2>&1; then
      exec fish
    fi
    EOF
    mkdir -p /tmp /run /etc
    # Runtime glibc wiring so unpatched binaries (VS Code Server's node and
    # code-server, extension native modules) can exec and resolve shared
    # libraries through standard FHS paths, equivalent to NixOS nix-ld.
    mkdir -p /lib /lib64 /usr/lib /usr/lib64 /usr/bin /sbin
    ln -sfn ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
    ln -sfn ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 /lib/ld-linux-x86-64.so.2
    for lib in libc.so.6 libm.so.6 libdl.so.2 libpthread.so.0 librt.so.1 libresolv.so.2 libnss_dns.so.2 libnss_files.so.2; do
      ln -sfn ${pkgs.glibc}/lib/\$lib /lib64/\$lib
      ln -sfn ${pkgs.glibc}/lib/\$lib /usr/lib/\$lib
      ln -sfn ${pkgs.glibc}/lib/\$lib /usr/lib64/\$lib
    done
    ln -sfn ${pkgs.stdenv.cc.cc.lib}/lib/libstdc++.so.6 /lib64/libstdc++.so.6
    ln -sfn ${pkgs.stdenv.cc.cc.lib}/lib/libstdc++.so.6 /usr/lib/libstdc++.so.6
    ln -sfn ${pkgs.stdenv.cc.cc.lib}/lib/libstdc++.so.6 /usr/lib64/libstdc++.so.6
    ln -sfn ${pkgs.libgcc}/lib/libgcc_s.so.1 /lib64/libgcc_s.so.1
    ln -sfn ${pkgs.libgcc}/lib/libgcc_s.so.1 /usr/lib/libgcc_s.so.1
    ln -sfn ${pkgs.libgcc}/lib/libgcc_s.so.1 /usr/lib64/libgcc_s.so.1
    ln -sfn ${pkgs.zlib}/lib/libz.so.1 /lib64/libz.so.1
    ln -sfn ${pkgs.zlib}/lib/libz.so.1 /usr/lib/libz.so.1
    ln -sfn ${pkgs.zlib}/lib/libz.so.1 /usr/lib64/libz.so.1
    # openssl: VS Code's vsce-sign extension-signature verifier dlopens
    # libssl at crypto time and SIGABRTs with "No usable version of libssl
    # was found" if absent.
    ln -sfn ${pkgs.openssl.out}/lib/libssl.so.3 /lib64/libssl.so.3
    ln -sfn ${pkgs.openssl.out}/lib/libssl.so.3 /usr/lib/libssl.so.3
    ln -sfn ${pkgs.openssl.out}/lib/libssl.so.3 /usr/lib64/libssl.so.3
    ln -sfn ${pkgs.openssl.out}/lib/libcrypto.so.3 /lib64/libcrypto.so.3
    ln -sfn ${pkgs.openssl.out}/lib/libcrypto.so.3 /usr/lib/libcrypto.so.3
    ln -sfn ${pkgs.openssl.out}/lib/libcrypto.so.3 /usr/lib64/libcrypto.so.3
    # 'sh' shebang needs /usr/bin/env; VS Code CLI's GNU prereq probes need
    # ldd and /sbin/ldconfig.
    ln -sfn ${pkgs.coreutils}/bin/env /usr/bin/env
    ln -sfn ${pkgs.glibc.bin}/bin/ldconfig /sbin/ldconfig
    ln -sfn ${pkgs.glibc.bin}/bin/ldd /usr/bin/ldd
    # VS Code Server's CLI checks /etc/NIXOS (not os-release) to detect NixOS
    # and then selects the default glibc server build. Do NOT add a musl loader
    # at /lib: the CLI's musl probe would then pick the Alpine/musl server,
    # whose musl node cannot run against the glibc libraries wired above.
    touch /etc/NIXOS
    cat > /etc/os-release <<'EOF'
    NAME="NixOS"
    ID=nixos
    ID_LIKE=""
    VERSION="25.11 (Xantusia)"
    VERSION_ID="25.11"
    PRETTY_NAME="NixOS 25.11 (Xantusia)"
    EOF
    chmod 1777 /tmp /run
    chmod 0755 /home/coder
    chown 1000:1000 /home/coder
    # Rootless podman. Three things it cannot supply for itself, all measured
    # rather than assumed:
    #   * /etc/subuid and /etc/subgid do not exist in this image at all, and
    #     without a range for the user, unpacking any real image dies with
    #     "potentially insufficient UIDs or GIDs available in user namespace
    #     (requested 0:42 for /etc/shadow)".
    #   * nixpkgs ships newuidmap/newgidmap at 0755. They must be setuid-root
    #     for a non-root user to claim a subordinate id range, so they are
    #     copied out of the read-only store and given the bit here.
    #   * /run/user/1000 (XDG_RUNTIME_DIR) is normally made by logind, and there
    #     is no logind in a container.
    echo 'coder:100000:65536' >> /etc/subuid
    echo 'coder:100000:65536' >> /etc/subgid
    cp ${pkgs.shadow}/bin/newuidmap /usr/bin/newuidmap
    cp ${pkgs.shadow}/bin/newgidmap /usr/bin/newgidmap
    chmod 4755 /usr/bin/newuidmap
    chmod 4755 /usr/bin/newgidmap
    mkdir -p /run/user/1000
    chown 1000:1000 /run/user/1000
    chmod 0700 /run/user/1000
    # Storage driver and cgroup manager are baked in rather than left to
    # autodetection, because the defaults are wrong for this pod specifically:
    # the workspace container has no CAP_SYS_ADMIN and '/' is not a shared
    # mount, so overlay/fuse storage cannot mount (there is no /dev/fuse either)
    # and the cgroup manager cannot delegate. vfs copies instead of mounting —
    # slower and hungrier on disk, and fine for a single long-lived database
    # container, which is the only thing this is for.
    mkdir -p /etc/containers
    cat > /etc/containers/storage.conf <<'EOF'
    [storage]
    driver = "vfs"
    EOF
    cat > /etc/containers/containers.conf <<'EOF'
    [engine]
    cgroup_manager = "cgroupfs"
    events_backend = "none"
    EOF
    mkdir -p /etc/nix
    cat > /etc/nix/nix.conf <<'EOF'
    sandbox = false
    experimental-features = nix-command flakes
    EOF
    # nix verifies TLS against the standard path, not SSL_CERT_FILE.
    ln -sfn /etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt
    # NOTE: /nix/var/nix is NOT created here — re-emitting a path under the
    # existing /nix dir in runAsRoot produces a duplicate entry in the layer
    # tar and `docker load` rejects it ("duplicates of file paths not
    # supported"). The template's root-phase startup creates it instead.
   '';
  # /nix/store ends up root-owned and read-only for the workspace user.
  # Writability for home-manager switches is not needed: HM is used
  # config-only against a writable profile under /nix/var/nix, and no chown
  # happens inside this build (it crashes the CI builder VM).
  extraCommands = "";
  config = {
    User = "1000:1000";
    WorkingDir = "/home/coder";
    Env = [
      "PATH=/home/coder/.nix-profile/bin:/bin:/usr/bin:/home/coder/.cargo/bin:/home/coder/.local/bin:/home/coder/.bun/bin"
      "HOME=/home/coder"
      "SHELL=/bin/bash"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "LD_LIBRARY_PATH=/lib64:/usr/lib64:/usr/lib"
      "XDG_RUNTIME_DIR=/run/user/1000"
    ];
    Cmd = [ "/bin/sh" ];
  };
}
