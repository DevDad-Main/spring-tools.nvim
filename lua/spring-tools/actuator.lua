local M = {}

M.endpoints = {
  {
    group = "Health",
    endpoints = {
      { path = "/actuator/health", method = "GET", description = "Application health status" },
      { path = "/actuator/health/{component}", method = "GET", description = "Health of a specific component" },
    },
  },
  {
    group = "Info",
    endpoints = {
      { path = "/actuator/info", method = "GET", description = "Application information" },
    },
  },
  {
    group = "Metrics",
    endpoints = {
      { path = "/actuator/metrics", method = "GET", description = "Available metric names" },
      { path = "/actuator/metrics/{name}", method = "GET", description = "Metric value by name" },
    },
  },
  {
    group = "Environment",
    endpoints = {
      { path = "/actuator/env", method = "GET", description = "Environment properties" },
      { path = "/actuator/env/{name}", method = "GET", description = "Specific property value" },
    },
  },
  {
    group = "Beans",
    endpoints = {
      { path = "/actuator/beans", method = "GET", description = "All Spring beans at runtime" },
    },
  },
  {
    group = "Mappings",
    endpoints = {
      { path = "/actuator/mappings", method = "GET", description = "All request mappings" },
    },
  },
  {
    group = "Configuration",
    endpoints = {
      { path = "/actuator/configprops", method = "GET", description = "Configuration properties with origins" },
    },
  },
  {
    group = "Loggers",
    endpoints = {
      { path = "/actuator/loggers", method = "GET", description = "Log levels" },
      { path = "/actuator/loggers/{name}", method = "GET", description = "Specific logger level" },
    },
  },
  {
    group = "Thread Dump",
    endpoints = {
      { path = "/actuator/threaddump", method = "GET", description = "Thread dump" },
    },
  },
  {
    group = "Heap Dump",
    endpoints = {
      { path = "/actuator/heapdump", method = "GET", description = "Heap dump (binary)" },
    },
  },
  {
    group = "Scheduled Tasks",
    endpoints = {
      { path = "/actuator/scheduledtasks", method = "GET", description = "Scheduled tasks" },
    },
  },
  {
    group = "Caches",
    endpoints = {
      { path = "/actuator/caches", method = "GET", description = "Cache information" },
    },
  },
  {
    group = "Shutdown",
    endpoints = {
      { path = "/actuator/shutdown", method = "POST", description = "Shutdown the application" },
    },
  },
}

return M
