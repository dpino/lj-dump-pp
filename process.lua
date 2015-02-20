#!/usr/bin/env luajit

local function readfile(file)
   local f = io.open(file, "rt")
   local content = f:read("*all")
   f:close()
   return content
end

--[[
if #arg == 0 then usage()
--]]
--

local function wrap(tag, class, text)
   return ("<%s %s>%s</%s>"):format(tag, class, text, tag)
end

local styles = [[
div.content {
   display: none;
}

.red {
   background: #f0f4ff;
}
]]

local javascript = [[
<script type="text/javascript" src="js/jquery.js"></script>
<script type="text/javascript">
   function init() {
      $('div.title').on('click', function() {
         $(this).next().toggle();
      });
   }
   window.addEventListener('load', init);
</script>
]]

local filename = "dump.html"
local content = readfile(filename)

local line, pos = "", 0
while true do
   line, pos = content:match("([^\n]+)\n()", pos)
   if line:match("</style>") then
      print(styles)
      print(line) 
      print(javascript)
      break
   end
   print(line)
end

local function print_trace(buffer, style)
   local content = table.concat(buffer, "\n")
   if style == "abort" then
      print((content):format("background: #ffaea0"))
   else
      print((content):format("background:  #f0f4ff"))
   end
end

local in_traces = false
local buffer = {}
local style = "normal"
while true do
   line, pos = content:match("([^\n]+)\n()", pos)
   if not line then break end
   if line:match('</pre>') then
      table.insert(buffer, line)
      print_trace(buffer, style)
      buffer = {}
      style = "normal"
   elseif line:match('<pre class="ljdump">') then
      table.insert(buffer, '<pre style="%s" class="ljdump">')
   elseif line:match("---- TRACE %d+ start") then
      table.insert(buffer, "<div class='title'>"..line.."</div>")
      table.insert(buffer, "<div class='content'>")
   elseif line:match("---- TRACE %d+ IR") then
      table.insert(buffer, "</div>")
      table.insert(buffer, "<div class='title'>"..line.."</div>")
      table.insert(buffer, "<div class='content'>")
   elseif line:match("---- TRACE %d+ mcode") then
      table.insert(buffer, "</div>")
      table.insert(buffer, "<div class='title'>"..line.."</div>")
      table.insert(buffer, "<div class='content'>")
   elseif line:match("---- TRACE %d+ normal") then
      table.insert(buffer, "</div>")
      table.insert(buffer, "<div class='title'>"..line.."</div>")
      style = "normal"
   elseif line:match("---- TRACE %d+ abort") then
      table.insert(buffer, "</div>")
      table.insert(buffer, "<div class='title'>"..line.."</div>")
      style = "abort"
   else
      table.insert(buffer, line)
   end
end
print(table.concat(buffer, "\n"))
