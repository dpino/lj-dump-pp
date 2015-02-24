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
div.title {
   cursor: pointer;
}

div.content {
   display: none;
}

div.summary {
   background: lightblue; 
   width: 220px; 
   border: solid 1px black
}

div.summary-line {
   cursor: pointer;
   padding: 4px;
   border-bottom: solid 1px black;
}

div.summary span {
   margin-top: 10px;
   padding: 8px;
}

.normal {
   background: lightblue;
}

.normal.selected {
   background: #9AC0CD;
}

.abort {
   background: #F64D54;
}

.abort.selected {
   background: #E32E30;
}

pre.ljdump {
   display: none;
   float: right;
   width: 1050px;
}
]]

local javascript = [[
<script type="text/javascript" src="js/jquery.js"></script>
<script type="text/javascript">
   function toggle_trace(target, id) {
      var node = $('#' + id);
      var result = node.toggle();
      var isHidden = node.is(":hidden");
      if (isHidden) {
         $(target).removeClass("selected");
      } else {
         $(target).addClass("selected");
      }
   }

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

local function print_trace(buffer, trace_id, style)
   local content = table.concat(buffer, "\n")
   if style == "abort" then
      print((content):format(trace_id, "background: #ffaea0;"))
   else
      print((content):format(trace_id, "background:  #f0f4ff;"))
   end
end

local traces_state = {}
local trace_id, filename

local in_traces = false
local buffer, summary = {}, {}
local style = "normal"
local id = 0
while true do
   line, pos = content:match("([^\n]+)\n()", pos)
   if not line then break end
   if line:match('</pre>') then
      table.insert(summary, ("<div class='summary-line %s' onclick='toggle_trace(this, %d);'><span>#%d - %s</span></div>")
         :format(style, id, trace_id, filename))
      table.insert(buffer, line)
      print_trace(buffer, id, style)
      -- Reset
      id = id + 1
      buffer = {}
      style = "normal"
   elseif line:match('<pre class="ljdump">') then
      table.insert(buffer, '<pre id="'..id..'" style="%s" class="ljdump">')
   elseif line:match("---- TRACE %d+ start %w+") then
      trace_id, filename = line:match("---- TRACE (%d+) start ([a-zA-Z0-9.:]+)")
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

print_trace(buffer, style)

print("<div class='summary'>")
for i, head in ipairs(summary) do
   print(head)
end
print("</div>")

print("</body></html>")
