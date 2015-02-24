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
      // Show all traces
      var text = "[All: " + $('.summary-line').length + "]";
      $('#traceState').contents().last().replaceWith(text);
   }

   var traceStates = {
      all: 0,
      aborted: 1,
      completed: 2
   };

   var traceState = traceStates.all;

   function switchTracesState(target) {
      var num;
      traceState = traceState + 1; 
      traceState = traceState % (Object.keys(traceStates).length);
      switch (traceState) {
         case traceStates.all:
            $('.summary-line').css("display", "block");
            var text = "[All: " + $('.summary-line').length + "]";
            $(target).contents().last().replaceWith(text);
         break;
         case traceStates.aborted:
            $('.summary-line').css("display", "none");
            $('.summary-line.abort').css("display", "block");
            var text = "[Aborted: " + $('.summary-line.abort').length + "]";
            $(target).contents().last().replaceWith(text);
         break;
         case traceStates.completed:
            $('.summary-line').css("display", "none");
            $('.summary-line.normal').css("display", "block");
            var text = "[Completed: " + $('.summary-line.normal').length + "]";
            $(target).contents().last().replaceWith(text);
      }
   }

   function expand_trace(target) {
      var container = $(target).parent().parent();
      var text = $(target).text();
      if (text == "[Expand]") {
         $(target).text("[Collapse]");
         $(container).find("div.content").show();
      } else {
         $(target).text("[Expand]");
         $(container).find("div.content").hide();
      }
   }

   function close_trace(id) {
      $('#' + id).hide();
      $('#summary-line-' + id).removeClass("selected");
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
      table.insert(summary, ("<div id='summary-line-"..id.."' class='summary-line %s' onclick='toggle_trace(this, %d);'><span>#%d - %s</span></div>")
         :format(style, id, trace_id, filename))
      table.insert(buffer, line)
      print_trace(buffer, id, style)
      -- Reset
      id = id + 1
      buffer = {}
      style = "normal"
   elseif line:match('<pre class="ljdump">') then
      table.insert(buffer, '<pre id="'..id..'" style="%s" class="ljdump">')
      table.insert(buffer, [[<span style='float: right; font-size: 10px; margin-top: -10px'>
         <a href='#' onclick="expand_trace(this);">[Expand]</a> | <a href='#' onclick="close_trace(]]..id..[[);">[X]</a> </span>
      ]])
   elseif line:match("---- TRACE %d+ start %w+") then
      trace_id = line:match("---- TRACE (%d+)")
      filename = line:match("([a-zA-Z0-9.:]+)$")
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

print([=[
<div style="font-size: 10px; font-face: Courier; margin-bottom: 4px">
   <span><a id="traceState" href="#" onclick="switchTracesState(this);">[All]</a></span>
</div>
]=])
print([[<div class="summary">]])
for i, head in ipairs(summary) do
   print(head)
end
print("</div>")

print("</body></html>")
