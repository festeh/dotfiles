require("gp").setup({
  chat_topic_gen_model = "gpt-5",
  agents = {
    {
      name = "ChatGPT4",
      chat = true,
      command = false,
      -- string with model name or table with model name and parameters
      model = { model = "gpt-4", temperature = 0.2, },
      -- system prompt (use this to specify the persona/role of the AI)
      system_prompt = "Hi.\n\n"
    },
    {
      name = "ChatGPT4_Turbo",
      chat = true,
      command = false,
      -- string with model name or table with model name and parameters
      model = { model = "gpt-4-1106-preview", temperature = 0.0, },
      -- system prompt (use this to specify the persona/role of the AI)
      system_prompt = "Hi.\n\n"
    }

  }
}
)
