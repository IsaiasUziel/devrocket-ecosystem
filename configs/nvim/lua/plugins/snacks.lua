return {
  "folke/snacks.nvim",
  opts = {
    explorer = {
      -- Esto hace que el explorador NO intente adivinar la raíz
      -- y use el directorio actual de trabajo (CWD)
      replace_netrw = true,
    },
  },
  keys = {
    -- Sobrescribimos el mapeo de LazyVim para <leader>e
    -- Forzamos que 'root' sea false para que use el directorio donde abriste nvim
    {
      "<leader>e",
      function()
        Snacks.explorer({ root = false })
      end,
      desc = "Explorer Snacks (CWD)",
    },
    -- Si alguna vez quieres el comportamiento original (basado en .git),
    -- puedes mantener <leader>E o mapearlo a otra tecla:
    {
      "<leader>fE",
      function()
        Snacks.explorer({ root = true })
      end,
      desc = "Explorer Snacks (Root Dir)",
    },
  },
}
