-- Quickly leap from point-to-point
return {
  "ggandor/leap.nvim",
  name = "leap",
  event = "VeryLazy",
  init = function()
    for _, _22_ in ipairs({ { { "n", "x", "o" }, "s", "<Plug>(leap-forward)", "Leap forward" }, { { "n", "x", "o" }, "S", "<Plug>(leap-backward)", "Leap backward" }, { { "x", "o" }, "x", "<Plug>(leap-forward-till)", "Leap forward till" }, { { "x", "o" }, "X", "<Plug>(leap-backward-till)", "Leap backward till" }, { { "n", "x", "o" }, "gs", "<Plug>(leap-from-window)", "Leap from window" } }) do
      local modes = _22_[1]
      local lhs = _22_[2]
      local rhs = _22_[3]
      local desc = _22_[4]
      for _0, mode in ipairs(modes) do
        if ((vim.fn.mapcheck(lhs, mode) == "") and (vim.fn.hasmapto(rhs, mode) == 0)) then
          vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
        else
        end
      end
    end
    vim.keymap.set({ "n", "o" }, "gS", function()
      require("leap.remote").action()
    end)
  end,
}
