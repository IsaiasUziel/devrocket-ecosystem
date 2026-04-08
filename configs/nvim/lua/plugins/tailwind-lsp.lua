return {
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, "tailwindcss") then
        table.insert(opts.ensure_installed, "tailwindcss")
      end
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.tailwindcss = {
        settings = {
          tailwindCSS = {
            classAttributes = {
              "class",
              "className",
              "class:list",
              "ngClass",
            },
            includeLanguages = {
              blade = "html",
              php = "html",
              astro = "html",
              vue = "html",
              svelte = "html",
            },
            experimental = {
              classRegex = {
                "cn\\(([^)]*)\\)",
                "clsx\\(([^)]*)\\)",
                "cva\\(([^)]*)\\)",
                "twMerge\\(([^)]*)\\)",
                "twJoin\\(([^)]*)\\)",
              },
            },
          },
        },
      }

      opts.setup = opts.setup or {}
      opts.setup.tailwindcss = function(_, server_opts)
        vim.lsp.config("tailwindcss", server_opts)
        vim.lsp.enable("tailwindcss")
        return true
      end
    end,
  },
}
