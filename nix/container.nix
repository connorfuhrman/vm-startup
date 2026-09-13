{
  pkgs,
  lib ? pkgs.lib,
  determinateNix,
  determinateNixd,
  nixConfPath,
  imageName ? "determinate-nix",
  imageTag ? determinateNix.version,
  sourceUrl ? "https://github.com/DeterminateSystems/determinate",
}:
let
  inherit (pkgs) dockerTools;
  nixbldGid = 30000;
  nologin = "${pkgs.shadow}/bin/nologin";
  nixbldMembers = lib.concatStringsSep "," (map (n: "nixbld${toString n}") (lib.range 1 32));
  passwdText =
    "root:x:0:0:root:/root:/bin/bash\n"
    + lib.concatStringsSep "\n" (
      map (
        n:
        "nixbld${toString n}:x:${toString (nixbldGid + n)}:${toString nixbldGid}:Nix build user ${toString n}:/var/empty:${nologin}"
      ) (lib.range 1 32)
    )
    + "\n";
  groupText = "root:x:0:\nnixbld:x:${toString nixbldGid}:${nixbldMembers}\n";
  nsswitchText = ''
    passwd: files
    group: files
    shadow: files
    hosts: files dns
    networks: files
  '';
  caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  nixProfile = pkgs.writeTextFile {
    name = "nix-profile";
    destination = "/etc/profile.d/nix.sh";
    text = ''
      export NIX_SSL_CERT_FILE=${caBundle}
      export SSL_CERT_FILE=${caBundle}
      export NIX_PATH=nixpkgs=flake:nixpkgs
    '';
  };
  pathEnv = lib.makeBinPath [ determinateNix determinateNixd pkgs.bashInteractive pkgs.coreutils-full pkgs.gnutar pkgs.gzip pkgs.gnugrep pkgs.gnused pkgs.gawk pkgs.xz pkgs.which pkgs.curl pkgs.wget pkgs.less pkgs.man pkgs.findutils pkgs.gitMinimal pkgs.shadow ];
  buildLayeredImage = if dockerTools ? buildLayeredImageWithNixDb then dockerTools.buildLayeredImageWithNixDb else dockerTools.buildLayeredImage;
in
buildLayeredImage {
  name = imageName;
  tag = imageTag;
  created = "now";
  enableFakechroot = true;
  contents = [ nixProfile determinateNix determinateNixd pkgs.bashInteractive pkgs.coreutils-full pkgs.gnutar pkgs.gzip pkgs.gnugrep pkgs.gnused pkgs.gawk pkgs.xz pkgs.which pkgs.curl pkgs.wget pkgs.less pkgs.man pkgs.cacert pkgs.findutils pkgs.gitMinimal pkgs.shadow ];
  extraCommands = ''
    mkdir -p usr/bin etc/nix etc/profile.d
    ln -sfn ../bin usr/bin
    ln -sfn bash bin/sh
    mkdir -p root .nix-defexpr/channels nix/var/nix/profiles/per-user/root
    ln -sfn /nix/var/nix/profiles/default nix/var/nix/profiles/per-user/root/profile
  '';
  fakeRootCommands = ''
    mkdir -p etc/nix etc/profile.d nix/var/nix/profiles/per-user/root root tmp
    cp ${nixConfPath} etc/nix/nix.conf
    cp ${pkgs.writeText "passwd" passwdText} etc/passwd
    cp ${pkgs.writeText "group" groupText} etc/group
    cp ${pkgs.writeText "nsswitch.conf" nsswitchText} etc/nsswitch.conf
    ln -sfn /nix/var/nix/profiles/default nix/var/nix/profiles/per-user/root/profile
    chmod 1777 tmp
  '';
  config = {
    Cmd = [ "/bin/bash" ];
    Env = [ "PATH=${pathEnv}" "NIX_SSL_CERT_FILE=${caBundle}" "SSL_CERT_FILE=${caBundle}" "NIX_PATH=nixpkgs=flake:nixpkgs" "NIX_BUILD_SHELL=/bin/bash" "ENV=/etc/profile.d/nix.sh" "BASH_ENV=/etc/profile.d/nix.sh" "PAGER=less" "USER=root" "HOME=/root" ];
    Labels = { "org.opencontainers.image.source" = sourceUrl; "dev.determinate.nix.version" = determinateNix.version; };
  };
}
