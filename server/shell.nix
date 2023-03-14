{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  buildInputs = [
    pkgs.tmux
    pkgs.nodePackages.typescript

  ];

  shellHook = ''
    tmux new-session -d -s servers "tsc -w"
    tmux split-window -t servers "watchexec --stdin-quit -w src -w lib -r 'spago run'"
    tmux select-layout -t servers even-vertical
    tmux attach -t servers
  '';
}
