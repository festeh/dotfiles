return {
  settings = {
    json = {
      schemas = require("schemastore").json.schemas({
        select = { "package.json", "Chrome Extension" },
      }),
      validate = { enable = true },
    },
  },
}
