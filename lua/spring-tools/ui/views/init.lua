local sidebar = require("spring-tools.ui.sidebar")

local order = { "dashboard", "beans", "endpoints", "tests", "config", "initializer" }
local views = {
  dashboard = require("spring-tools.ui.views.dashboard"),
  beans = require("spring-tools.ui.views.beans"),
  endpoints = require("spring-tools.ui.views.endpoints"),
  tests = require("spring-tools.ui.views.tests"),
  config = require("spring-tools.ui.views.config"),
  initializer = require("spring-tools.ui.views.initializer"),
}

for _, name in ipairs(order) do
  sidebar.register_view(name, views[name])
end

return views
