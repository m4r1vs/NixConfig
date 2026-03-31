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

local function switchToOpencodeAndRunCMD(cmd)
  require("avante.api").switch_provider("opencode")
  vim.cmd(cmd)
end

return {
  "yetone/avante.nvim",
  version = false,
  lazy = true,
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
    {
      "<leader>AA",
      function()
        switchToOpencodeAndRunCMD("AvanteToggle")
      end,
      mode = "n"
    },
    {
      "<leader>aM",
      function()
        switchToOpencodeAndRunCMD("AvanteACPModes")
      end,
      mode = "n"
    },
    {
      "<leader>am",
      ":<cr>",
      function()
        switchToOpencodeAndRunCMD("AvanteACPModels")
      end,
      mode = "n"
    },
  },
  opts = {
    selection = {
      enabled = false,
      hint_display = "none",
    },
    provider = "openai",
    auto_suggestions_provider = "openai_nano",
    providers = {
      openai = {
        endpoint = "https://api.openai.com/v1",
        model = "gpt-5.3-codex",
        api_key_name = "AVANTE_OPENAI_API_KEY",
      },
      openai_nano = {
        __inherited_from = "openai",
        endpoint = "https://api.openai.com/v1",
        model = "gpt-5.4-nano",
        api_key_name = "AVANTE_OPENAI_API_KEY",
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
    mode = "agentic",
    input = {
      provider = "native",
    },
    behaviour = {
      auto_suggestions = false,
      auto_set_highlight_group = true,
      auto_set_keymaps = true,
      auto_apply_diff_after_generation = true,
      support_paste_from_clipboard = true,
      minimize_diff = true,
      enable_token_counting = true,
      auto_add_current_file = true,
      auto_approve_tool_permissions = true,
      confirmation_ui_style = "inline_buttons",
      acp_follow_agent_locations = true,
    },
    acp_providers = {
      ["opencode"] = {
        command = "opencode",
        args = { "acp" }
      },
      ["gemini-cli"] = {
        command = "gemini",
        args = { "--acp", "--approval-mode=yolo" },
        env = {
          NODE_NO_WARNINGS = "1",
        },
        auth_method = "oauth-personal",
      },
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
