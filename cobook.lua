dofile("urlcode.lua")
dofile("table_show.lua")

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')

local downloaded = {}
local addedtolist = {}

--ignore urls:
downloaded["https://cobook.co/static/styles/cobook.css?v=15a05b5b71d981cd51eb4ea10a59c348"] = true
downloaded["https://cobook.co/static/styles/mobile.css?v=771b34c9912699690f8e675db01d867d"] = true
downloaded["https://cobook.co/static/images/favicon.png?v=dd4be2076393ff77d6294149f09f1ffb"] = true
downloaded["https://cobook.co/static/images/nav/icon.svg?v=e227ed5bbdf7fa0ffbcd15e3cd0b69ce"] = true

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]
  local parenturl = parent["url"]
  local html = nil
  
  if downloaded[url] == true or addedtolist[url] == true then
    return false
  end
  
  if item_type == "cobook" and (downloaded[url] ~= true and addedtolist[url] ~= true) then
    if string.match(url, "/"..item_value) and string.match(url, "cobook%.co") then
      return verdict
    elseif html == 0 then
      return verdict
    else
      return false
    end
  end
  
end


wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil
  
  local function check(url)
    if (downloaded[url] ~= true and addedtolist[url] ~= true) and not string.match(url, "/static/") then
      table.insert(urls, { url=url })
      addedtolist[url] = true
    end
  end

  if item_type == "cobook" then
    if string.match(url, "https?://cobook%.co/"..item_value) then
      html = read_file(file)
      for newurl in string.gmatch(html, '(https?://[^"]+)"') do
        if string.match(newurl, "%.amazonaws%.com/img%.cobook%.co") or (string.match(newurl, "/"..item_value) and string.match(newurl, "cobook%.co")) then
          check(newurl)
        end
      end
    end
    if string.match(url, "https?://[^/]+/img%.cobook%.co.+") then
      nurl = string.match(url, "https?://[^/]+/(img%.cobook%.co.+)")
      newurl = "http://"..nurl
      check(newurl)
    end
  end
  
  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  local status_code = http_stat["statcode"]
  last_http_statcode = status_code
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()
  
  if (status_code >= 200 and status_code <= 399) then
    if string.match(url["url"], "https://") then
      local newurl = string.gsub(url["url"], "https://", "http://")
      downloaded[newurl] = true
    else
      downloaded[url["url"]] = true
    end
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404) then
    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 5")

    tries = tries + 1

    if tries >= 20 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      return wget.actions.EXIT
    else
      return wget.actions.CONTINUE
    end
  elseif status_code == 0 then
    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 10")

    tries = tries + 1

    if tries >= 10 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  -- We're okay; sleep a bit (if we have to) and continue
  -- local sleep_time = 0.1 * (math.random(500, 5000) / 100.0)
  local sleep_time = 0

  --  if string.match(url["host"], "cdn") or string.match(url["host"], "media") then
  --    -- We should be able to go fast on images since that's what a web browser does
  --    sleep_time = 0
  --  end

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end
