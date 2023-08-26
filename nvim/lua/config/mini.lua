require("mini.ai").setup()
require("mini.align").setup()
-- require("mini.animate").setup()
require("mini.basics").setup(
  {
    options = {
      basic = true,
      extra_ui = false,
    }
  }
)
-- require("mini.bracketed").setup()
require("mini.bufremove").setup()
require("mini.indentscope").setup()
-- require("mini.jump").setup()

local starter = require("mini.starter")
starter.setup(
  {
    items = {
      starter.sections.recent_files(5, true, true),
      starter.sections.telescope(),
    },
    evaluate_single = true,
  }
)
