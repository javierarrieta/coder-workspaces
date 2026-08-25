{ pkgs }:
let
  # tests fail in the container build env (indent/cd/path check scripts)
  fish = pkgs.fish.overrideAttrs (old: {
    doCheck = false;
  });
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
    pathsToLink = [
      "/bin"
      "/etc"
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
    ln -sfn ${pkgs.openssl}/lib/libssl.so.3 /lib64/libssl.so.3
    ln -sfn ${pkgs.openssl}/lib/libssl.so.3 /usr/lib/libssl.so.3
    ln -sfn ${pkgs.openssl}/lib/libssl.so.3 /usr/lib64/libssl.so.3
    ln -sfn ${pkgs.openssl}/lib/libcrypto.so.3 /lib64/libcrypto.so.3
    ln -sfn ${pkgs.openssl}/lib/libcrypto.so.3 /usr/lib/libcrypto.so.3
    ln -sfn ${pkgs.openssl}/lib/libcrypto.so.3 /usr/lib64/libcrypto.so.3
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
    ];
    Cmd = [ "/bin/sh" ];
  };
}
