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

div.searchbar {
   position: fixed;
   left: 10px;
   top: 10px;
   z-index: 100;
   width: 95%;
   margin-bottom: 10px;
}

div.searchbar input {
   padding: 2px;
}

body {
   margin-top: 40px;
}

]]

local lines = {}

local function generate_lines_array(varname)
   local buffer = {}
   local current_trace_id = -1

   table.insert(buffer, 'var '..varname..' = {')
   for _, line in ipairs(lines) do
      local trace_id, data = line:match("^(%d+)-(.+)$")
      if current_trace_id == trace_id then
         table.insert(buffer, "'"..data.."',")
      else
         if current_trace_id ~= -1 then table.insert(buffer, "},") end
         table.insert(buffer, "'"..trace_id.."' = {")
         current_trace_id = trace_id
      end
   end
   table.insert(buffer, '};')
   return table.concat(buffer, "\n")
end


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
      showAll();
   }

   var traceStates = {
      all: 0,
      aborted: 1,
      completed: 2
   };

   var traceState = traceStates.all;

   function switchTracesState(event) {
      event.preventDefault();
      switch (nextTraceState()) {
         case traceStates.all:
            showAll();
         break;
         case traceStates.aborted:
            showAborted();
         break;
         case traceStates.completed:
            showCompleted();
      }
   }

   function nextTraceState() {
      traceState = (traceState + 1) % (Object.keys(traceStates).length);
      return traceState;
   }

   function clearTextSearch() {
      $('#txtSearch').val('')
      showAll();
   }

   function showAll() {
      $('.summary-line').css("display", "block");
      var text = "[All: " + $('.summary-line').length + "]";
      $('#traceState').contents().last().replaceWith(text);
   }

   function showAborted() {
      $('.summary-line').css("display", "none");
      $('.summary-line.abort').css("display", "block");
      var text = "[Aborted: " + $('.summary-line.abort').length + "]";
      $('#traceState').contents().last().replaceWith(text);
   }

   function showCompleted() {
      $('.summary-line').css("display", "none");
      $('.summary-line.normal').css("display", "block");
      var text = "[Completed: " + $('.summary-line.normal').length + "]";
      $('#traceState').contents().last().replaceWith(text);
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

   function doSearch(event) {
      if (event.keyCode != 13) return;
      $('.summary-line').hide();
      $('div.content').each(function(i, item) {
         var haystack = $(item).text();
         var needle = $('#txtSearch').val();
         if (haystack.contains(needle)) {
            var title = findTraceTitle($(item).prev());
            showSummaryLine(summaryLineTitleFormat(title.text()));
         }
      });
   }

   function findTraceTitle(title) {
      // Is in IR section
      if (title.text().match(/^---- TRACE \d+ IR/)) {
         return title.prev().prev();
      }
      // Is in MCODE section
      if (title.text().match(/^---- TRACE \d+ mcode/)) {
         return title.prev().prev().prev().prev();
      }
      return title;
   }

   function summaryLineTitleFormat(text) {
      return text.replace("---- TRACE ", "#").replace(" start", " -");
   }

   function showSummaryLine(trace_name) {
      $('div.summary').find('span').each(function(i, item) {
         var str = $(item).text();
         if (str == trace_name) {
            $(item).parent().show();
         }
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
local lines = {}
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
      if not lines[id] then lines[id] = {} end
      table.insert(lines[id], line)
   end
end

print_trace(buffer, style)

print([=[

<div class="searchbar">
   <form action="">
      <input id="txtSearch" style="width: 95%; background: #ff9" display: inline" type="text" placeholder="Type text to find and press return" onkeypress="doSearch(event);"/>
      <input style="display: inline" type="button" value="Clear" onclick="clearTextSearch();" />
   </form>
</div>
<div style="font-size: 10px; font-face: Courier; margin-bottom: 4px">
   <span><a id="traceState" href="#" onclick="switchTracesState(event);">[All]</a></span>
</div>
]=])
print([[<div class="summary">]])
for i, head in ipairs(summary) do
   print(head)
end
print("</div>")

print("</body></html>")
