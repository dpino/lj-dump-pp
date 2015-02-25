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
   top: 0px;
   padding-top: 10px;
   width: 98%;
   background: #646d7e;
   border-bottom: black solid 1px;
}

div.searchbar input {
   padding: 2px;
}

body {
   margin: 60px 10px;
   padding: 0px;
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

   var traceStates = {
      all: 0,
      aborted: 1,
      completed: 2,
      search: 3,
   };

   var traceState = traceStates.all;

   var searchResults = [];

   function toggleAll() {
      var text = $('#openAll').text();
      if (text.match(/Open/)) {
         closeAll();
         openAll();
         $('#openAll').text('[Close all]');
      } else {
         closeAll();
         $('#openAll').text('[Open all]');
      }
   }

   function closeAll() {
      $('div.summary-line').each(function(i, summaryTitle) {
         var id = $(summaryTitle).attr('id');
         var matched = id.match(/(\d+)/)
         if (matched) {
            closeTrace($(summaryTitle), $('#' + matched[1]));
         }
      });
      $('#openAll').text('[Open all]');
   }

   function closeTrace(summaryTitle, trace) {
      summaryTitle.removeClass("selected");
      trace.hide();
   }

   function openAll() {
      getSummaryLinesByState().each(function(i, summaryTitle) {
         var id = $(summaryTitle).attr('id');
         var matched = id.match(/(\d+)/)
         if (matched) {
            openTrace($(summaryTitle), $('#' + matched[1]));
         }
      });
   }

   function openTrace(summaryTitle, trace) {
      summaryTitle.addClass("selected");
      trace.show();
      trace.find("div").show();
   }

   function getSummaryLinesByState() {
      switch (traceState) {
         case traceStates.all:
            return $('.summary-line');
         break;
         case traceStates.aborted:
            return $('.summary-line.abort');
         break;
         case traceStates.completed:
            return $('.summary-line.normal');
         break;
         case traceStates.search:
            return $(getSearchResultsSummaryLines());
         break;
      }
   }

   function getSearchResultsSummaryLines() {
      var result = [];
      var set = new Set(searchResults);
      $('div.summary').find('span').each(function(i, item) {
         var trace_name = $(item).text();
         if (set.has(trace_name)) {
            result.push($(item).parent());
         }
      });
      return result;
   }

   function toggleTrace(summaryTitle, traceId) {
      var trace = $('#' + traceId);
      trace.toggle();
      expandTrace(trace);
      toggleSummaryTitleSelection(summaryTitle, trace.is(":hidden"));
   }

   function toggleSummaryTitleSelection(summaryTitle, unselect) {
      if (unselect) {
         $(summaryTitle).removeClass("selected");
      } else {
         $(summaryTitle).addClass("selected");
      }
   }

   function expandTrace(container) {
      var target = container.find("a").first();
      if (target.text() == "[Expand]") {
         $(target).text("[Collapse]");
         $(container).find("div.content").show();
      } else {
         $(target).text("[Expand]");
         $(container).find("div.content").hide();
      }
   }

   function init() {
      $('div.title').on('click', function() {
         $(this).next().toggle();
      });
      showAll();
   }

   function showAll() {
      $('.summary-line').show();
      var text = "[All: " + $('.summary-line').length + "]";
      $('#traceState').contents().last().replaceWith(text);
   }

   function switchTracesState(event) {
      event.preventDefault();
      closeAll();
      nextTraceState();
      showTraces();
   }

   function showTraces()  {
      switch (traceState) {
         case traceStates.all:
            showAll();
         break;
         case traceStates.aborted:
            showAborted();
         break;
         case traceStates.completed:
            showCompleted();
         break;
         case traceStates.search:
            if (searchResults.length != 0) {
               showSearchResults();
            } else {
               showAll();
               nextTraceState();
            }
      }
   }

   function nextTraceState() {
      traceState = (traceState + 1) % (Object.keys(traceStates).length);
      return traceState;
   }

   function clearTextSearch() {
      $('#txtSearch').val('')
      resetState();
   }

   function resetState() {
      traceState = traceStates.all;
      closeAll();
      showAll();
   }

   function showAborted() {
      $('.summary-line').hide();
      $('.summary-line.abort').show();
      var text = "[Aborted: " + $('.summary-line.abort').length + "]";
      $('#traceState').contents().last().replaceWith(text);
   }

   function showCompleted() {
      $('.summary-line').hide();
      $('.summary-line.normal').show();
      var text = "[Completed: " + $('.summary-line.normal').length + "]";
      $('#traceState').contents().last().replaceWith(text);
   }

   function showSearchResults() {
      $('.summary-line').hide();
      var text = "[Search: " + searchResults.length + "]";
      $('#traceState').contents().last().replaceWith(text);
      for (trace of getSearchResultsSummaryLines()) {
         trace.show();
      }
   }

   function close_trace(id) {
      $('#' + id).hide();
      $('#summary-line-' + id).removeClass("selected");
   }

   function doSearch(event) {
      if (event.keyCode != 13) return;

      searchResults = [];
      resetState();

      var needle = $('#txtSearch').val();
      if (needle.length == 0) {
         return;
      }

      traceState = traceStates.search;
      $('div.title').each(function(i, item) {
         var haystack = $(item).text();
         if (haystack.contains(needle)) {
            var title = findTraceTitle($(item));
            searchResults.push(summaryLineTitleFormat(title.text()));
         }
      });
      $('div.content').each(function(i, item) {
         var haystack = $(item).text();
         if (haystack.contains(needle)) {
            var title = findTraceTitle($(item).prev());
            searchResults.push(summaryLineTitleFormat(title.text()));
         }
      });

      // Remove duplicates
      searchResults = [...Set(searchResults)];

      // Show search results
      showSearchResults();
   }

   function findTraceTitle(title) {
      // Is not 'start' title
      if (title.text().match(/[^\d+ start]/)) {
         return title.prev().prev();
      }
      return title;
   }

   function summaryLineTitleFormat(text) {
      var matched, traceId, filename;
      matched = text.match(/^---- TRACE (\d+)/);
      if (matched) {
         traceId = matched[1];
      }
      matched = filename = text.match(/([\.:0-9a-zA-Z]+)$/);
      if (matched) {
         filename = matched[1];
      }
      return "#" + traceId +" - " + filename;
      return result;
   }

   window.addEventListener('load', init);
</script>
]]

local filename = "dump.html"
local content = readfile(filename)

local line, pos = "", 0

local function print_search_bar()
print([=[
<div class="searchbar">
   <form action="" style="padding: 0px 10px;">
      <input id="txtSearch" style="width: 95%; background: #ff9"; display: inline" type="text" placeholder="Type text to find and press return" onkeypress="doSearch(event);"/>
      <input style="display: inline" type="button" value="Clear" onclick="clearTextSearch();" />
   </form>
</div>
]=])
end

print("<html>")
print("<head><title></title></head>")
while true do
   line, pos = content:match("([^\n]+)\n()", pos)
   if line:match("</style>") then
      print(styles)
      print(line) 
      print(javascript)
      print("<body>")
      print_search_bar()
      print([[
         <div style="font-size: 10px; font-face: Courier; margin-bottom: 4px">
            <span><a id="traceState" href="#" onclick="switchTracesState(event);">[All]</a></span>
            <span><a id="openAll" href="#" onclick="toggleAll();">[Open all]</a></span>
         </div>
      ]])
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
      table.insert(summary, ("<div id='summary-line-"..id.."' class='summary-line %s' onclick='toggleTrace(this, %d);'><span>#%d - %s</span></div>")
         :format(style, id, trace_id, filename))
      table.insert(buffer, line)
      print_trace(buffer, id, style)
      -- Reset
      id = id + 1
      buffer = {}
      style = "normal"
   elseif line:match('<pre class="ljdump">') then
      table.insert(buffer, '<pre id="'..id..'" style="%s" class="ljdump">')
      table.insert(buffer, [[
         <span style='float: right; font-size: 10px; margin-top: -10px'>
            <a href='#' onclick="expandTrace($(this).parent().parent());">[Expand]</a> | <a href='#' onclick="close_trace(]]..id..[[);">[X]</a>
         </span>
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

print([[<div class="summary">]])
for i, head in ipairs(summary) do
   print(head)
end
print("</div>")

print("</body></html>")
