{ pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix

  ];

  system.stateVersion = "22.11";
  boot.cleanTmpDir = true;
  zramSwap.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # SSH Config

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.hostName = "satifile";

  services.openssh.enable = true;
  services.openssh.passwordAuthentication = false;

  users.users.root.openssh.authorizedKeys.keys = [

    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPL7ne15QcheWJXIdX8SMb7b+4AD4dCR1WpnjUq6RLUM ryo_o"
  ];

  programs.ssh.extraConfig = ''
    Host *
        IdentityFile /etc/ssh/ssh_host_ed25519_key
  '';

  programs = {
    fish.enable = true;

    neovim.enable = true;
    neovim.viAlias = true;
    neovim.vimAlias = true;
    neovim.defaultEditor = true;
    neovim.configure = {
      customRC = ''
        set number
        set relativenumber
      '';
    };
  };

  users.defaultUserShell = pkgs.fish;

  # Use NGINX as reverse proxy
  security.acme.defaults.email = "mail@satifile.com";
  security.acme.acceptTerms = true;

  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [

    bottom
    ctop
    docker-compose
    fish
    git
    neovim
    tldr
  ];

  users.users.root.extraGroups = [ "docker" ];

  # Nginx
  services.nginx.enable = true;
  services.nginx.recommendedProxySettings = true;
  services.nginx.recommendedTlsSettings = true;

  # Satifile
  services.nginx.virtualHosts."satifile.com" = {
    forceSSL = true;
    enableACME = true;
    root = "/var/www/satifile";
    locations."/api" = {
      proxyPass = "http://localhost:8080";
      extraConfig = ''
        client_max_body_size 5000M;
        proxy_pass_request_headers on;
      '';

    };
    locations."/" = {
      extraConfig = ''
        try_files $uri /index.html;
        client_max_body_size 5000M;
        proxy_pass_request_headers on;
      '';
    };

    locations."/error" = { return = "502"; };

  };

  # Return to main domain
  services.nginx.virtualHosts."wetransfersats.com" = {
    locations."/".return = "301 https://satifile.com$request_uri";
  };
  services.nginx.virtualHosts."wetransferbits.com" = {
    locations."/".return = "301 https://satifile.com$request_uri";
  };
  services.nginx.virtualHosts."sats4files.com" = {
    locations."/".return = "301 https://satifile.com$request_uri";
  };
  services.nginx.virtualHosts."files4sats.com" = {
    locations."/".return = "301 https://satifile.com$request_uri";
  };

  # 21.tools
  services.nginx.virtualHosts."21.tools" = {
    forceSSL = true;
    enableACME = true;
    root = "/var/www/21-tools";
  };

  services.nginx.virtualHosts."twentyone.tools" = {
    forceSSL = true;
    enableACME = true;
    root = "/var/www/21-tools";
  };

}

