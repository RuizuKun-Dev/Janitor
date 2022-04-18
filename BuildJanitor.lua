local ffi = require("ffi")

ffi.cdef("\r\n\tint printf(const char * Format, ...);\r\n")
os.execute(string.format("rojo build -o Janitor.rbxm default.project.json"))
os.execute(string.format("rojo build -o Janitor.rbxmx default.project.json"))
ffi.C.printf("Built Janitor!\n")

return 1
