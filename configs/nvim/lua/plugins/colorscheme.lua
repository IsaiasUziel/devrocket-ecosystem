-- Colorscheme configuration for LazyVim
-- devrocket-rouge is a standalone colorscheme inspired by rouge-theme for VSCode
-- https://github.com/josefaidt/rouge-theme

return {
  -- devrocket-rouge colorscheme (external plugin)
  -- Repository: https://github.com/IsaiasUziel/devrocket-rouge.nvim
  {
    "IsaiasUziel/devrocket-rouge.nvim",
    name = "devrocket-rouge",
    priority = 1000,
    lazy = false,
    opts = {
      transparent_background = false,
      italic_comments = true,
      italic_keywords = true,
      underline_links = false,
      bold_functions = false,
      dim_inactive = false,
    },
    config = function(_, opts)
      require("devrocket-rouge").setup(opts)
    end,
  },
  {
    "Gentleman-Programming/gentleman-kanagawa-blur",
    name = "gentleman-kanagawa-blur",
    priority = 1000,
    opts = {
      transparent_background = false, -- disables setting the background color.
    },
  },
  {
    "rebelot/kanagawa.nvim",
    priority = 1000,
    lazy = false,
    config = function()
      require("kanagawa").setup({
        compile = false, -- enable compiling the colorscheme
        undercurl = true, -- enable undercurls
        commentStyle = { italic = true },
        functionStyle = {},
        keywordStyle = { italic = true },
        statementStyle = { bold = true },
        typeStyle = {},
        transparent = true, -- do not set background color
        dimInactive = false, -- dim inactive window `:h hl-NormalNC`
        terminalColors = true, -- define vim.g.terminal_color_{0,17}
        colors = { -- add/modify theme and palette colors
          palette = {},
          theme = {
            wave = {},
            lotus = {},
            dragon = {},
            all = {
              ui = {
                bg_gutter = "none", -- set bg color for normal background
                bg_sidebar = "none", -- set bg color for sidebar like nvim-tree
                bg_float = "none", -- set bg color for floating windows
              },
            },
          },
        },
        overrides = function(colors) -- add/modify highlights
          return {
            LineNr = { bg = "none" },
            NormalFloat = { bg = "none" },
            FloatBorder = { bg = "none" },
            FloatTitle = { bg = "none" },
            TelescopeNormal = { bg = "none" },
            TelescopeBorder = { bg = "none" },
            LspInfoBorder = { bg = "none" },
          }
        end,
        theme = "wave", -- Load "wave" theme
        background = { -- map the value of 'background' option to a theme
          dark = "wave", -- try "dragon" !
          light = "lotus",
        },
      })
    end,
  },
  {
    "rebelot/kanagawa.nvim",
    priority = 1000,
    lazy = false,
  },
  {
    "olimorris/onedarkpro.nvim",
    priority = 1000,
    lazy = false,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      -- To switch themes, change colorscheme to: "devrocket-rouge", "gentleman-kanagawa-blur", "kanagawa", "onedarkpro"
      colorscheme = "devrocket-rouge",
      colorschemes = { "devrocket-rouge", "gentleman-kanagawa-blur", "kanagawa", "onedarkpro" },
    },
  },
}
