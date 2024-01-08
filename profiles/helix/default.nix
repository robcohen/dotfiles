{
  inputs,
  pkgs,
  config,
  ...
}: {

  programs.helix = {
    enable = true;
    programs.helix.settings = {
      theme = "onedark"

      [editor]
      auto-pairs = false
      bufferline = "multiple"
      cursorline = true
      cursor-shape.insert = "bar"
      gutters = ["diff", "line-numbers", "spacer", "spacer"]
      indent-guides.render = true
      indent-guides.character = "▏"
      line-number = "absolute"
      shell = ["fish", "-c"]
    };
  };
}
