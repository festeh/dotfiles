require("cmake-tools").setup {
  cmake_command = "cmake", -- this is used to specify cmake command path
  cmake_regenerate_on_save = false,
  cmake_notifications = {
    enabled = false,
  }
  -- cmake_executor = "quickfix",
}
