return {
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, "emmet_language_server") then
        table.insert(opts.ensure_installed, "emmet_language_server")
      end
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.emmet_language_server = {
        filetypes = {
          "astro",
          "css",
          "eruby",
          "html",
          "javascriptreact",
          "less",
          "php",
          "sass",
          "scss",
          "svelte",
          "typescriptreact",
          "vue",
          "blade",
        },
        init_options = {
          includeLanguages = {
            blade = "html",
            php = "html",
          },
        },
      }
    end,
  },
}
