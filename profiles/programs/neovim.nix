{ config, pkgs, lib, ... }:

{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    extraPackages = with pkgs; [
      # LSP servers
      lua-language-server
      nil                    # Nix LSP
      nodePackages.typescript-language-server
      nodePackages.vscode-langservers-extracted  # HTML, CSS, JSON, ESLint
      pyright                # Python LSP
      rust-analyzer          # Rust LSP
      gopls                  # Go LSP
      terraform-ls           # Terraform LSP
      yaml-language-server
      marksman               # Markdown LSP

      # Formatters
      stylua                 # Lua formatter
      nixpkgs-fmt            # Nix formatter
      nodePackages.prettier  # JS/TS/HTML/CSS formatter
      black                  # Python formatter
      rustfmt                # Rust formatter
      gofumpt                # Go formatter
      shfmt                  # Shell formatter

      # Linters
      shellcheck             # Shell linter
      hadolint               # Dockerfile linter

      # Tools
      tree-sitter
      fd
      ripgrep
    ];

    plugins = with pkgs.vimPlugins; [
      # Theme
      {
        plugin = catppuccin-nvim;
        type = "lua";
        config = ''
          require("catppuccin").setup({
            flavour = "mocha",
            transparent_background = false,
            term_colors = true,
            integrations = {
              cmp = true,
              gitsigns = true,
              nvimtree = true,
              treesitter = true,
              telescope = {
                enabled = true,
              },
              mason = true,
              which_key = true,
            },
          })
          vim.cmd.colorscheme "catppuccin"
        '';
      }

      # File explorer
      {
        plugin = nvim-tree-lua;
        type = "lua";
        config = ''
          require("nvim-tree").setup({
            view = {
              width = 35,
              side = "left",
            },
            renderer = {
              icons = {
                show = {
                  file = true,
                  folder = true,
                  folder_arrow = true,
                  git = true,
                },
              },
            },
            filters = {
              dotfiles = false,
            },
            git = {
              enable = true,
              ignore = false,
            },
          })
          vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { silent = true })
          vim.keymap.set('n', '<leader>o', ':NvimTreeFocus<CR>', { silent = true })
        '';
      }
      nvim-web-devicons

      # Treesitter
      {
        plugin = nvim-treesitter.withAllGrammars;
        type = "lua";
        config = ''
          require("nvim-treesitter.configs").setup({
            highlight = { enable = true },
            indent = { enable = true },
            incremental_selection = {
              enable = true,
              keymaps = {
                init_selection = "<C-space>",
                node_incremental = "<C-space>",
                scope_incremental = false,
                node_decremental = "<bs>",
              },
            },
          })
        '';
      }

      # LSP
      {
        plugin = nvim-lspconfig;
        type = "lua";
        config = ''
          local lspconfig = require('lspconfig')
          local capabilities = require('cmp_nvim_lsp').default_capabilities()

          -- Key mappings for LSP
          local on_attach = function(client, bufnr)
            local opts = { noremap = true, silent = true, buffer = bufnr }
            vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
            vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
            vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
            vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
            vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
            vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
            vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
            vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
            vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format({ async = true }) end, opts)
            vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
            vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
            vim.keymap.set('n', '<leader>d', vim.diagnostic.open_float, opts)
          end

          -- LSP servers setup
          local servers = {
            'lua_ls',
            'nil_ls',
            'ts_ls',
            'pyright',
            'rust_analyzer',
            'gopls',
            'terraformls',
            'yamlls',
            'marksman',
            'html',
            'cssls',
            'jsonls',
          }

          for _, lsp in ipairs(servers) do
            lspconfig[lsp].setup({
              on_attach = on_attach,
              capabilities = capabilities,
            })
          end

          -- Special config for lua_ls
          lspconfig.lua_ls.setup({
            on_attach = on_attach,
            capabilities = capabilities,
            settings = {
              Lua = {
                diagnostics = {
                  globals = { 'vim' },
                },
                workspace = {
                  library = vim.api.nvim_get_runtime_file("", true),
                  checkThirdParty = false,
                },
                telemetry = { enable = false },
              },
            },
          })
        '';
      }

      # Autocompletion
      {
        plugin = nvim-cmp;
        type = "lua";
        config = ''
          local cmp = require('cmp')
          local luasnip = require('luasnip')

          cmp.setup({
            snippet = {
              expand = function(args)
                luasnip.lsp_expand(args.body)
              end,
            },
            mapping = cmp.mapping.preset.insert({
              ['<C-b>'] = cmp.mapping.scroll_docs(-4),
              ['<C-f>'] = cmp.mapping.scroll_docs(4),
              ['<C-Space>'] = cmp.mapping.complete(),
              ['<C-e>'] = cmp.mapping.abort(),
              ['<CR>'] = cmp.mapping.confirm({ select = true }),
              ['<Tab>'] = cmp.mapping(function(fallback)
                if cmp.visible() then
                  cmp.select_next_item()
                elseif luasnip.expand_or_jumpable() then
                  luasnip.expand_or_jump()
                else
                  fallback()
                end
              end, { 'i', 's' }),
              ['<S-Tab>'] = cmp.mapping(function(fallback)
                if cmp.visible() then
                  cmp.select_prev_item()
                elseif luasnip.jumpable(-1) then
                  luasnip.jump(-1)
                else
                  fallback()
                end
              end, { 'i', 's' }),
            }),
            sources = cmp.config.sources({
              { name = 'nvim_lsp' },
              { name = 'luasnip' },
              { name = 'path' },
            }, {
              { name = 'buffer' },
            }),
            window = {
              completion = cmp.config.window.bordered(),
              documentation = cmp.config.window.bordered(),
            },
          })
        '';
      }
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      luasnip
      cmp_luasnip

      # Telescope
      {
        plugin = telescope-nvim;
        type = "lua";
        config = ''
          local telescope = require('telescope')
          local builtin = require('telescope.builtin')

          telescope.setup({
            defaults = {
              file_ignore_patterns = { "node_modules", ".git/" },
              mappings = {
                i = {
                  ["<C-j>"] = "move_selection_next",
                  ["<C-k>"] = "move_selection_previous",
                },
              },
            },
          })

          vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find files' })
          vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
          vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
          vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Help tags' })
          vim.keymap.set('n', '<leader>fr', builtin.oldfiles, { desc = 'Recent files' })
          vim.keymap.set('n', '<C-p>', builtin.find_files, { desc = 'Find files' })
        '';
      }
      plenary-nvim

      # Git integration
      {
        plugin = gitsigns-nvim;
        type = "lua";
        config = ''
          require('gitsigns').setup({
            signs = {
              add = { text = '│' },
              change = { text = '│' },
              delete = { text = '_' },
              topdelete = { text = '‾' },
              changedelete = { text = '~' },
            },
            on_attach = function(bufnr)
              local gs = package.loaded.gitsigns
              local opts = { buffer = bufnr }

              vim.keymap.set('n', ']c', function()
                if vim.wo.diff then return ']c' end
                vim.schedule(function() gs.next_hunk() end)
                return '<Ignore>'
              end, {expr=true, buffer = bufnr})

              vim.keymap.set('n', '[c', function()
                if vim.wo.diff then return '[c' end
                vim.schedule(function() gs.prev_hunk() end)
                return '<Ignore>'
              end, {expr=true, buffer = bufnr})

              vim.keymap.set('n', '<leader>hs', gs.stage_hunk, opts)
              vim.keymap.set('n', '<leader>hr', gs.reset_hunk, opts)
              vim.keymap.set('n', '<leader>hp', gs.preview_hunk, opts)
              vim.keymap.set('n', '<leader>hb', function() gs.blame_line{full=true} end, opts)
            end,
          })
        '';
      }

      # Status line
      {
        plugin = lualine-nvim;
        type = "lua";
        config = ''
          require('lualine').setup({
            options = {
              theme = 'catppuccin',
              component_separators = { left = '''''', right = '''''' },
              section_separators = { left = '''''', right = '''''' },
            },
            sections = {
              lualine_a = {'mode'},
              lualine_b = {'branch', 'diff', 'diagnostics'},
              lualine_c = {'filename'},
              lualine_x = {'encoding', 'fileformat', 'filetype'},
              lualine_y = {'progress'},
              lualine_z = {'location'}
            },
          })
        '';
      }

      # Indent guides
      {
        plugin = indent-blankline-nvim;
        type = "lua";
        config = ''
          require("ibl").setup({
            indent = { char = "│" },
            scope = { enabled = true },
          })
        '';
      }

      # Autopairs
      {
        plugin = nvim-autopairs;
        type = "lua";
        config = ''
          require("nvim-autopairs").setup({})
          local cmp_autopairs = require('nvim-autopairs.completion.cmp')
          local cmp = require('cmp')
          cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())
        '';
      }

      # Comment toggling
      {
        plugin = comment-nvim;
        type = "lua";
        config = ''
          require('Comment').setup()
        '';
      }

      # Which-key for keybinding help
      {
        plugin = which-key-nvim;
        type = "lua";
        config = ''
          require("which-key").setup({})
        '';
      }

      # Surround
      {
        plugin = nvim-surround;
        type = "lua";
        config = ''
          require("nvim-surround").setup({})
        '';
      }

      # Better buffer management
      {
        plugin = bufferline-nvim;
        type = "lua";
        config = ''
          require("bufferline").setup({
            options = {
              diagnostics = "nvim_lsp",
              offsets = {
                { filetype = "NvimTree", text = "File Explorer", highlight = "Directory", separator = true }
              },
            },
          })
          vim.keymap.set('n', '<S-h>', ':BufferLineCyclePrev<CR>', { silent = true })
          vim.keymap.set('n', '<S-l>', ':BufferLineCycleNext<CR>', { silent = true })
          vim.keymap.set('n', '<leader>bp', ':BufferLineTogglePin<CR>', { silent = true })
          vim.keymap.set('n', '<leader>bc', ':BufferLinePickClose<CR>', { silent = true })
        '';
      }

      # Tmux navigation
      {
        plugin = vim-tmux-navigator;
        type = "lua";
        config = ''
          vim.g.tmux_navigator_no_mappings = 1
          vim.keymap.set('n', '<C-h>', ':TmuxNavigateLeft<CR>', { silent = true })
          vim.keymap.set('n', '<C-j>', ':TmuxNavigateDown<CR>', { silent = true })
          vim.keymap.set('n', '<C-k>', ':TmuxNavigateUp<CR>', { silent = true })
          vim.keymap.set('n', '<C-l>', ':TmuxNavigateRight<CR>', { silent = true })
        '';
      }

      # Markdown preview
      markdown-preview-nvim
    ];

    extraLuaConfig = ''
      -- General settings
      vim.g.mapleader = ' '
      vim.g.maplocalleader = ' '

      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.mouse = 'a'
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.hlsearch = false
      vim.opt.wrap = false
      vim.opt.breakindent = true
      vim.opt.tabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.expandtab = true
      vim.opt.signcolumn = 'yes'
      vim.opt.updatetime = 250
      vim.opt.timeoutlen = 300
      vim.opt.splitright = true
      vim.opt.splitbelow = true
      vim.opt.termguicolors = true
      vim.opt.scrolloff = 8
      vim.opt.sidescrolloff = 8
      vim.opt.cursorline = true
      vim.opt.undofile = true
      vim.opt.clipboard = 'unnamedplus'

      -- Key mappings
      vim.keymap.set('n', '<leader>w', ':w<CR>', { desc = 'Save file' })
      vim.keymap.set('n', '<leader>q', ':q<CR>', { desc = 'Quit' })
      vim.keymap.set('n', '<leader>x', ':x<CR>', { desc = 'Save and quit' })
      vim.keymap.set('n', '<Esc>', ':noh<CR>', { silent = true })

      -- Window navigation
      vim.keymap.set('n', '<leader>sv', ':vsplit<CR>', { desc = 'Split vertical' })
      vim.keymap.set('n', '<leader>sh', ':split<CR>', { desc = 'Split horizontal' })

      -- Buffer navigation
      vim.keymap.set('n', '<leader>bd', ':bdelete<CR>', { desc = 'Delete buffer' })

      -- Move lines
      vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move line down' })
      vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move line up' })

      -- Keep cursor centered
      vim.keymap.set('n', '<C-d>', '<C-d>zz')
      vim.keymap.set('n', '<C-u>', '<C-u>zz')
      vim.keymap.set('n', 'n', 'nzzzv')
      vim.keymap.set('n', 'N', 'Nzzzv')

      -- Diagnostic appearance
      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          border = 'rounded',
          source = 'always',
        },
      })

      -- Custom signs for diagnostics
      local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
      end
    '';
  };
}
