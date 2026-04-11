return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}

      local formatters = {
        blade = { "blade-formatter" },
        javascript = { "biome" },
        typescript = { "biome" },
        javascriptreact = { "biome" },
        typescriptreact = { "biome" },
        json = { "biome" },
        vue = { "prettier" },
        astro = { "prettier" },
        css = { "prettier" },
        scss = { "prettier" },
        html = { "prettier" },
        yaml = { "prettier" },
      }

      opts.formatters_by_ft = vim.tbl_deep_extend("force", opts.formatters_by_ft, formatters)
    end,
  },
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      local null_ls = require("null-ls")

      opts.sources = opts.sources or {}
      vim.list_extend(opts.sources, {
        null_ls.builtins.diagnostics.eslint,
      })
    end,
  },
}
