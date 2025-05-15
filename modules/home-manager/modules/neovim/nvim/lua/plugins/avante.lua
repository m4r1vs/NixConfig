return {
  "m4r1vs/avante.nvim",
  version = false,
  keys = {
    { "<leader>aa", "<cmd>AvanteToggle<cr>", mode = "n" },
    { "<leader>aa", "<cmd>AvanteAsk<cr>",    mode = "v" },
    { "<leader>ae", "<cmd>AvanteEdit<cr>",   mode = "v" },
  },
  opts = {
    provider = "gemini",
    mappings = {
      ask = "<leader>tt"
    },
    gemini = {
      endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
      model = "gemini-2.5-pro-preview-05-06",
      timeout = 30000,
      temperature = 0,
      api_key_name = "cmd:secret-tool lookup google_gemini password",
      max_tokens = 40960,
    },
    openai = {
      endpoint = "https://api.openai.com/v1",
      model = "gpt-4o",
      timeout = 30000,
      temperature = 0,
      api_key_name = "cmd:secret-tool lookup openai password",
      --reasoning_effort = "medium",
    },
    rag_service = {
      enabled = false,
      host_mount = os.getenv("HOME"),
      runner = "nix",
      provider = "openai",
      llm_model = "",
      embed_model = "",
      endpoint = "https://api.openai.com/v1",
      api_key_name = "cmd:secret-tool lookup openai password",
      docker_extra_args = "",
    },
    behaviour = {
      enable_token_counting = false,
      support_paste_from_clipboard = false,
      auto_suggestions = false,
    },
    hints = {
      enabled = false,
    },
  },
  build = "make",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "echasnovski/mini.pick",
    "nvim-telescope/telescope.nvim",
    "hrsh7th/nvim-cmp",
    "ibhagwan/fzf-lua",
    "nvim-tree/nvim-web-devicons",
    {
      "HakonHarnes/img-clip.nvim",
      event = "VeryLazy",
      opts = {
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          use_absolute_path = true,
        },
      },
    },
    {
      'MeanderingProgrammer/render-markdown.nvim',
      opts = {
        file_types = { "Avante" },
      },
      ft = { "Avante" },
    },
  },
}
