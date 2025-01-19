{ config, pkgs, ... }:

{
  programs.zellij = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      default_layout = "compact";
      session_serialization = false;
      default_shell = "fish";

      keybinds = {
        normal = {
            "bind \"Ctrl g\"" = {
              "SwitchToMode" = "Locked";
            };
            "bind \"Alt t\"" = {
              "NewPane" ={};
            };
            "unbind \"Ctrl p\""= {};
            "unbind \"Ctrl n\""= {};
            "unbind \"Ctrl b\""= {};
        };
        locked = {
            "bind \"Ctrl g\"" = {
              "SwitchToMode" = "Normal";
            };
        };
      };

      pane_frames = false;
      copy_commandd = "wl-copy";
    };
  };

  # template layout
  # Column 1: Connecting to the server 1
  # Column 2: Connecting to the server 2
  # Column 3: Connecting to the server 3
  # Row 1: output of journalctl about app
  # Row 2: output of journalctl about nginx
  # Row 3: output of journalctl about mysql
  # Row 4: output of htop
  # Row 5: terminal for deployment
  xdg.configFile."zellij/layouts/isucon.kdl".text = ''
    layout {
        pane split_direction="horizontal" {
            // Column 1: Server 1
            pane split_direction="vertical" {
                // Row 1: App logs (prepare journalctl command)
                pane command="ssh" {
                    args "s1" "bash -ic 'echo -n \"sudo journalctl -fu \" > /dev/tty; bash'"
                }
                // Row 2: Nginx logs
                pane command="ssh" {
                    args "s1" "sudo journalctl -fu nginx"
                }
                // Row 3: MySQL logs
                pane command="ssh" {
                    args "s1" "sudo journalctl -fu mysqld"
                }
                // Row 4: htop
                pane command="ssh" {
                    args "s1" "htop"
                }
                // Row 5: deployment terminal
                pane command="ssh" {
                    args "s1"
                }
            }
            // Column 2: Server 2
            pane split_direction="vertical" {
                pane command="ssh" {
                    args "s2" "bash -ic 'echo -n \"sudo journalctl -fu \" > /dev/tty; bash'"
                }
                pane command="ssh" {
                    args "s2" "sudo journalctl -fu nginx"
                }
                pane command="ssh" {
                    args "s2" "sudo journalctl -fu mysqld"
                }
                pane command="ssh" {
                    args "s2" "htop"
                }
                pane command="ssh" {
                    args "s2"
                }
            }
            // Column 3: Server 3
            pane split_direction="vertical" {
                pane command="ssh" {
                    args "s3" "bash -ic 'echo -n \"sudo journalctl -fu \" > /dev/tty; bash'"
                }
                pane command="ssh" {
                    args "s3" "sudo journalctl -fu nginx"
                }
                pane command="ssh" {
                    args "s3" "sudo journalctl -fu mysqld"
                }
                pane command="ssh" {
                    args "s3" "htop"
                }
                pane command="ssh" {
                    args "s3"
                }
            }
        }
    }
  '';
}
