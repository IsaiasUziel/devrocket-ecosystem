return {
  ------------------------------------------------------------------
  -- 🌳 TREESITTER (extend, no override)
  ------------------------------------------------------------------
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      local languages = {
        "php",
        "blade",
        "html",
        "css",
        "javascript",
        "typescript",
        "tsx",
        "jsx",
        "astro",
        "vue",
        "svelte",
        "json",
        "yaml",
        "toml",
        "bash",
        "markdown",
        "markdown_inline",
      }

      for _, lang in ipairs(languages) do
        if not vim.tbl_contains(opts.ensure_installed, lang) then
          table.insert(opts.ensure_installed, lang)
        end
      end

      opts.highlight = opts.highlight or { enable = true }
      opts.indent = opts.indent or { enabled = true }

      opts.ignore_install = vim.list_extend(opts.ignore_install or {}, { "phpdoc" })
    end,
  },

  ------------------------------------------------------------------
  -- 🌲 CONTEXT
  ------------------------------------------------------------------
  {
    "nvim-treesitter/nvim-treesitter-context",
    opts = {
      max_lines = 5,
      trim_scope = "outer",
    },
  },

  ------------------------------------------------------------------
  -- 🌈 RAINBOW (correcto)
  ------------------------------------------------------------------
  {
    "hiphish/rainbow-delimiters.nvim",
    event = "VeryLazy",
    config = function()
      local rd = require("rainbow-delimiters")

      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = rd.strategy.global,
          php = false, -- Disable rainbow-delimiters for PHP (WordPress templates)
        },
        query = {
          [""] = "rainbow-delimiters",
        },
        highlight = {
          "RainbowDelimiterRed",
          "RainbowDelimiterYellow",
          "RainbowDelimiterBlue",
          "RainbowDelimiterOrange",
          "RainbowDelimiterGreen",
          "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
        },
      }
    end,
  },

}
