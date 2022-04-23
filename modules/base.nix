{ pkgs, config, ... }:

{
  _module.args.buildVM = false;

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
     '';
  };

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "uk";
  };

  users.users.root = {
    openssh.authorizedKeys.keyFiles = [
    ];
  };

  users.users.k-ot = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    atop
    fish
    git
    htop
    tmux
    vim_configurable
    wget
    git-crypt
  ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.passwordAuthentication = true;
  programs.mosh.enable = true;
}
