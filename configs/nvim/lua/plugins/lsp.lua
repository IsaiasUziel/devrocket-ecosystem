return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ui = opts.ui or {}
    end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      local servers = {
        "ts_ls",
        "html",
        "cssls",
        "astro",
        "vue_ls",
        "svelte",
        "lua_ls",
      }

      for _, server in ipairs(servers) do
        if not vim.tbl_contains(opts.ensure_installed, server) then
          table.insert(opts.ensure_installed, server)
        end
      end
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      opts.servers.lua_ls = {
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim" },
            },
          },
        },
      }

      opts.servers.ts_ls = opts.servers.ts_ls or {}
    end,
  },
}
