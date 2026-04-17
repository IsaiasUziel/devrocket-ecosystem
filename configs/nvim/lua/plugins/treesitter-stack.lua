return {
  ------------------------------------------------------------------
  -- 🌳 TREESITTER (extend, no override)
  ------------------------------------------------------------------
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- 1. Asegurar que opts sea una tabla
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

      -- 2. Forzar el resaltado por defecto
      opts.highlight = {
        enable = true,
        -- Mantener el resaltado legacy de Vim para PHP (útil en templates mixtos)
        additional_vim_regex_highlighting = { "php" },
      }

      opts.incremental_selection = opts.incremental_selection
        or {
          enable = true,
          keymaps = {
            init_selection = "gnn",
            node_incremental = "grn",
            scope_incremental = "grc",
            node_decremental = "grm",
          },
        }

      opts.ignore_install = vim.list_extend(opts.ignore_install or {}, { "phpdoc" })

      opts.indent = opts.indent or { enable = true }

      -- 3. ¡IMPORTANTE! Retornar la tabla modificada
      return opts
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
  -- {
  --   "hiphish/rainbow-delimiters.nvim",
  --   event = "VeryLazy",
  --   config = function()
  --     local rd = require("rainbow-delimiters")
  --
  --     vim.g.rainbow_delimiters = {
  --       strategy = {
  --         [""] = rd.strategy.global,
  --       },
  --       query = {
  --         [""] = "rainbow-delimiters",
  --       },
  --       highlight = {
  --         "RainbowDelimiterRed",
  --         "RainbowDelimiterYellow",
  --         "RainbowDelimiterBlue",
  --         "RainbowDelimiterOrange",
  --         "RainbowDelimiterGreen",
  --         "RainbowDelimiterViolet",
  --         "RainbowDelimiterCyan",
  --       },
  --     }
  --   end,
  -- },
}
