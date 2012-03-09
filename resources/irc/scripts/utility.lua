﻿---------------------------------------------------------------------
-- Project: irc
-- Author: MCvarial
-- Contact: mcvarial@gmail.com
-- Version: 1.0.0
-- Date: 31.10.2010
---------------------------------------------------------------------

executeSQLCreateTable("ircmutes","player TEXT, serial TEXT, reason TEXT, admin TEXT, mute TEXT, duration TEXT")
local mutes = {}

------------------------------------
-- Utility
------------------------------------

function getAdminMessage (time,author)
	outputServerLog("Time: "..time..", Author: "..author)
	return "Hello, world!"
end

function getNickFromRaw (raw)
	return string.sub(gettok(raw,1,33),2)
end

function getMessageFromRaw (raw)
	local t = split(string.sub(raw,2,-2),58)
	table.remove(t,1)
	return table.concat(t,":")
end

local chars = {"+","%","@","&","~"}
function getNickAndLevel (nick)
	for i,char in ipairs (chars) do
		if string.sub(nick,1,1) == char then
			nick = string.sub(nick,2)
			return nick,i
		end
	end
	return nick,0
end

function toletters (string)
	local t = {}
	for i=1,string.len(string) do
		table.insert(t,string.sub(string,1,1))
		string = string.sub(string,2)
	end
	return t
end

function getPlayerFromPartialName (name)
	local matches = {}
	for i,player in ipairs (getElementsByType("player")) do
		if getPlayerName(player) == name then
			return player
		end
		if string.find(string.lower(getPlayerName(player)),string.lower(name),0,false) then
			table.insert(matches,player)
		end
	end
	if #matches == 1 then
		return matches[1]
	end
	return false
end

function getResourceFromPartialName (name)
	local matches = {}
	for i,resource in ipairs (getResources()) do
		if getResourceName(resource) == name then
			return resource
		end
		if string.find(string.lower(getResourceName(resource)),string.lower(name),0,false) then
			table.insert(matches,resource)
		end
	end
	if #matches == 1 then
		return matches[1]
	end
	return false
end

function getTimeStamp ()
	local time = getRealTime()
	return "["..(time.year + 1900).."-"..(time.month+1).."-"..time.monthday.." "..time.hour..":"..time.minute..":"..time.second.."]"
end

_setPlayerMuted = setPlayerMuted
function setPlayerMuted (player,muted,reason,admin,time)
	if muted then
		executeSQLInsert("ircmutes","'"..tostring(getPlayerName(player)).."','"..tostring(getPlayerSerial(player)).."','"..tostring(reason).."','"..tostring(admin).."','"..tostring(getRealTime().timestamp*1000).."','"..tostring(time).."'")
		mutes[player] = setTimer(setPlayerMuted,time,1,player,false)
	else
		executeSQLDelete("ircmutes","serial = '"..tostring(getPlayerSerial(player)).."'")
		if mutes[player] then
			mutes[player] = nil
		end
	end
	return _setPlayerMuted(player,muted)
end

addEventHandler("onPlayerUnmute",root,
	function ()
		executeSQLDelete("ircmutes","serial = '"..tostring(getPlayerSerial(source)).."'")
		if mutes[source] then
			mutes[source] = nil
		end
	end
)

addEventHandler("onPlayerJoin",root,
	function ()
		local result = executeSQLSelect("ircmutes","serial,reason,mute,duration","serial = '"..getPlayerSerial(source).."'")
		if result and result[1] then
			local time = (tonumber(result[1]["mute"])+tonumber(result[1]["duration"]))-(getRealTime().timestamp*1000)
			if time < 50 then
				executeSQLDelete("ircmutes","serial = '"..tostring(getPlayerSerial(source)).."'")
			else
				_setPlayerMuted(source,true)
				mutes[source] = setTimer(setPlayerMuted,time,1,source,false)
			end
		end
	end
)

addEventHandler("onPlayerQuit",root,
	function ()
		if mutes[source] then
			killTimer(mutes[source])
			mutes[source] = nil
		end
	end
)

addEventHandler("onResourceStart",resourceRoot,
	function ()
		local results = executeSQLSelect("ircmutes","serial,mute,duration")
		if type(results) == "table" then
			for i,result in ipairs (results) do
				local mutetime = tonumber(result["mute"])
				local duration = tonumber(result["duration"])
				if mutetime and duration and (mutetime+duration) < (getRealTime().timestamp)*1000 then
					for i,player in ipairs (getElementsByType("player")) do
						if getPlayerSerial(player) == result["serial"] then
							_setPlayerMuted(player,false)
							outputChatBox("* "..getPlayerName(player).." has been unmuted",root,255,0,0)
						end
					end
					executeSQLDelete("ircmutes","serial = '"..tostring(result["serial"]).."'")
				end
			end
		end
	end
)

local times = {}
times["ms"] = 1
times["sec"] = 1000
times["secs"] = 1000
times["second"] = 1000
times["seconds"] = 1000
times["min"] = 60000
times["mins"] = 60000
times["minute"] = 60000
times["minutes"] = 60000
times["hour"] = 3600000
times["hours"] = 3600000
times["day"] = 86400000
times["days"] = 86400000
times["week"] = 604800000
times["weeks"] = 604800000
times["month"] = 2592000000
times["months"] = 2592000000
function toMs (time)
	if not time then return false end
	time = string.sub(time,2,-2)
	local t = split(time,32)
	local factor = 0
	local ms = 0
	for i,v in ipairs (t) do
		if tonumber(v) then
			factor = tonumber(v)
		elseif times[v] then
			ms = ms + (factor * times[v])
		end
	end
	return ms
end

function msToTimeStr(ms)
	if not ms then
		return ''
	end
	local centiseconds = tostring(math.floor(math.fmod(ms, 1000)/10))
	if #centiseconds == 1 then
		centiseconds = '0' .. centiseconds
	end
	local s = math.floor(ms / 1000)
	local seconds = tostring(math.fmod(s, 60))
	if #seconds == 1 then
		seconds = '0' .. seconds
	end
	local minutes = tostring(math.floor(s / 60))
	return minutes .. ':' .. seconds .. ':' .. centiseconds
end

function getTimeString (timeMs)
	local weeks = math.floor(timeMs/604800000)
	timeMs = timeMs - weeks * 604800000
	
	local days = math.floor(timeMs/86400000)
	timeMs = timeMs - days * 86400000
	
	local hours = math.floor(timeMs/3600000)
	timeMs = timeMs - hours * 3600000
	
	local minutes = math.floor(timeMs/60000)
	timeMs = timeMs - minutes * 60000
	
	local seconds = math.floor(timeMs/1000)
	
	return string.format("%dwks %ddays %dhrs %dmins %dsecs ",weeks,days,hours,minutes,seconds)
end

function getNumberFromVersion (version)
	local p1,p2,p3 = unpack(split(version,46))
	return tonumber((100*tonumber(p1))+(10*tonumber(p2))+(tonumber(p3)))
end

_addBan = addBan
function addBan (...)
	if getVersion().number < 260 then
		local t = {...}
		t[4] = nil
		return _addBan(unpack(t))
	else
		return _addBan(...)
	end
end