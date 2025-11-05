local function loadAPIKeysAndRunVimCMD(cmd)
  local function set_env_from_op(env_var, op_path)
    if vim.env[env_var] and vim.env[env_var] ~= "" then return end
    local handle = io.popen(string.format('op read "%s"', op_path))
    if handle then
      local key = handle:read("*a")
      handle:close()
      if key then
        vim.env[env_var] = key:gsub("%s+$", "")
      end
    end
  end
  set_env_from_op("AVANTE_OPENAI_API_KEY", "op://Private/OpenAI/credential")
  set_env_from_op("AVANTE_GEMINI_API_KEY", "op://Private/Gemini/credential")
  set_env_from_op("TAVILY_API_KEY", "op://Private/Tavily/credential")
  vim.cmd(cmd)
end

return {
  "yetone/avante.nvim",
  version = false,
  event = "VeryLazy",
  keys = {
    {
      "<leader>aa",
      function()
        loadAPIKeysAndRunVimCMD("AvanteToggle")
      end,
      mode = "n"
    },
    {
      "<leader>aa",
      function()
        loadAPIKeysAndRunVimCMD("AvanteAsk")
      end,
      mode = "v"
    },
    {
      "<leader>ae",
      function()
        loadAPIKeysAndRunVimCMD("AvanteEdit")
      end,
      mode = "v"
    },
  },
  opts = {
    selection = {
      enabled = true,
      hint_display = "none",
    },
    instructions_file = "avante.md",
    provider = "openai",
    providers = {
      openai = {
        endpoint = "https://api.openai.com/v1",
        model = "gpt-4.1",
        timeout = 30000,
        context_window = 128000,
        support_previous_response_id = true,
        extra_request_body = {
          temperature = 0.75,
          max_completion_tokens = 16384,
          reasoning_effort = "medium",
        },
      },
      gemini = { -- API key set in zsh config
        endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
        model = "gemini-2.5-pro",
        timeout = 15000,
        context_window = 1048576,
        use_ReAct_prompt = true,
        extra_request_body = {
          generationConfig = {
            temperature = 0.75,
          },
        },
      },
    },
    acp_providers = {
      ["gemini-cli"] = {
        command = "gemini",
        args = { "--experimental-acp", "--approval-mode=yolo" },
        env = {
          NODE_NO_WARNINGS = "1",
        },
        auth_method = "oauth-personal",
      },
    },
    behaviour = {
      auto_approve_tool_permissions = true,
    },
    windows = {
      spinner = {
        generating = { "·", "✢", "∗", "✻", "✽" },
        thinking = { "🤯", "🤯", "🙄", "🙄" },
      },
    },
    web_search_engine = {
      provider = "tavily",
      proxy = nil,
      providers = {
      },
    },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-mini/mini.pick",
    "nvim-telescope/telescope.nvim",
    "hrsh7th/nvim-cmp",
    "ibhagwan/fzf-lua",
    "stevearc/dressing.nvim",
    "folke/snacks.nvim",
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
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
  },
}
