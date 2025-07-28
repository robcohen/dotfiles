{ inputs, pkgs, config, ... }:
{
  programs.htop = {
    enable = true;
    settings = {
      show_cpu_frequency = true;
      show_cpu_temperature = true;
      show_program_path = false;
      highlight_base_name = true;
      highlight_megabytes = true;
      highlight_threads = true;
      tree_view = true;
      header_margin = true;
      detailed_cpu_time = true;
      color_scheme = 0;
      delay = 15;
      left_meters = [ "LeftCPUs2" "Memory" "Swap" ];
      right_meters = [ "RightCPUs2" "Tasks" "LoadAverage" "Uptime" ];
    };
  };
}
