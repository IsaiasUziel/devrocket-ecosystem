return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      local languages = {
        -- Backend / Laravel
        "php",
        "blade",

        -- Frontend core
        "html",
        "css",
        "javascript",
        "typescript",
        "tsx",
        "jsx",

        -- Component frameworks
        "astro",
        "vue",
      }

      for _, lang in ipairs(languages) do
        if not vim.tbl_contains(opts.ensure_installed, lang) then
          table.insert(opts.ensure_installed, lang)
        end
      end
    end,
  },
}
