-- Plugin for converting channels lists from coolstream receivers
-- Author focus.cst@gmail.com
-- License GPL v2
-- Copyright (C) 2013 CoolStream International Ltd

-- flag to test as plain script, without xupnpd - cfg not defined in this case
local cst_test =  false

if not cfg then
cfg={}
cfg.tmp_path='/tmp/'
cfg.feeds_path='/tmp/'
cfg.debug=1
cst_test = true
end

function cst_debug(level, msg)
	if cfg.debug>level then
		print(msg)
	end
end

function isFile(name)
    if type(name)~="string" then return false end
    local f = io.open(name)
    if f then
        f:close()
        return true
    end
    return false
end

function getLogoPathfroNneutrino()
	local f = io.open("/var/tuxbox/config/neutrino.conf", "r")
	if f then
		for line in f:lines() do
			local logopath = line:match("logo_hdd_dir=(.*)")
			if (logopath) then
			  	print(logopath)
				return logopath
			end
		end
		f:close()
	end
	return "/share/tuxbox/neutrino/icons/logo"
end

function getLogo(LogoPath, id, name)
	local NeutrinoPath = "/share/tuxbox/neutrino/icons/logo"
	Path = {LogoPath,"/var/tuxbox/icons/logo"}
	if(NeutrinoPath ~= LogoPath) then
		Path[3] = NeutrinoPath
	end
	local x=5
	if string.sub(id ,5,5) == '0' then 
		x = x + 1
	end
	id = string.sub(id ,x,16)
	
	chan = {name,id}
	for v, varPath in pairs(Path) do 
		for v2, varChan in pairs(chan) do 
			file = varPath .."/" .. varChan
			if(isFile(file .. ".png")) then
				return file .. ".png"
			end
			if(isFile(file .. ".jpg")) then
				return file .. ".jpg"
			end
		end
	end
	return nil
	
end

function cst_get_bouquets(s)
	local btable={}
	for string in string.gmatch(s, "(.-)%c") do
		if string then
			cst_debug(1, "########## bouquet="..string)
			local num = string.match(string, "%d+");
			if num then
				local len = string.len(num);
				local name = string.sub(string, len+1);
				btable[num] = name
				cst_debug(1, "num="..num.." name="..btable[num]);
			end
			--break; -- one bouquet
		end
	end
	return btable
end

function cst_get_channels(s)
	local ctable={}
	for string in string.gmatch(s, "(.-)%c") do
		idx = 1;
		if string then
			cst_debug(1, "########## channel="..string)
			local num = string.match(string, "%d+");
			if num then
				local len = string.len(num);
				local rest = string.sub(string, len+1);
				local id = string.match(rest, "%x+ ");
				len = string.len(id);
				local name = string.sub(rest, len+2);
				cst_debug(1, "num="..num.." id="..id.." name="..name)
				if id and name then
					table.insert(ctable, {id, name});
					idx = idx + 1;
				end
			end
		end
 	end	
	return ctable
end

-- all bouquets
-- local burl = "getbouquets"
-- only favorites
local burl = "getbouquets?fav=true&mode=all"

-- without epg
-- local curl = "getbouquet?bouquet="
-- with epg
local curl = "getbouquet?epg=true&mode=all&bouquet="

function cst_updatefeed(feed,friendly_name)
	local rc=false
	local feedspath = cfg.feeds_path
	if not friendly_name then
		friendly_name = feed
	end
	local cst_url = 'http://'..feed..'/control/'

	cst_debug(0, "url:"..cst_url..burl)
	local bouquets_data =  http.download(cst_url..burl)
	local bouquets =cst_get_bouquets(bouquets_data)

	if not bouquets then
		return rc
	end
	local LogoPath = getLogoPathfroNneutrino()
	local sysip =www_location
	sysip=sysip:match('(http://%d*.%d*.%d*.%d*):*.')
	local bindex
	local bouquett = {}
	for bindex,bouquett in pairs(bouquets) do
		local cindex
		local channelt = {}
		cst_debug(0,"url:".."\""..cst_url..curl..bindex.."\"")
		local xmlbouquet_data =  http.download(cst_url..curl..bindex)
		local bouquet = cst_get_channels(xmlbouquet_data)
		if bouquet then
			local bnum = string.format("%03d", bindex)
	    		local m3ufilename = cfg.tmp_path.."cst_"..friendly_name.."_bouquet_"..bnum..".m3u"
			cst_debug(0, m3ufilename)
	    		local m3ufile = io.open(m3ufilename,"w")
			m3ufile:write("#EXTM3U name=\""..bouquett.." ("..friendly_name..")\" plugin=coolstream type=ts\n")
			for cindex,channelt in pairs(bouquet) do
				local id = channelt[1];
				local name = channelt[2];

				local logo = getLogo(LogoPath, id, name)
				if logo == nil then
					m3ufile:write("#EXTINF:0,"..name.."\n")
				else
					m3ufile:write("#EXTINF:0 logo="..sysip..logo .." ,"..name.."\n")
				end

				-- m3ufile:write(cst_url.."zapto?"..id.."\n")
				m3ufile:write("http://"..feed..":31339/id="..id.."\n")
			end
			m3ufile:close()
			os.execute(string.format('mv %s %s',m3ufilename,feedspath))
			rc=true
		end
	end
	return rc
end

function cst_read_url(url)
	local string =  http.download(url)

	return string
end

function cst_zapto(urlbase,id)
	local zap = urlbase.."/control/zapto?"..id;
	cst_read_url(zap)
end

function cst_sendurl(cst_url,range)
	local i,j,baseurl = string.find(cst_url,"(.+):.+")
	cst_debug(0, "cst_sendurl: url="..cst_url.." baseurl="..baseurl)

--	i,j,id = string.find(cst_url,".*id=(.+)")
--	local surl = baseurl.."/control/standby"
--	local standby = cst_read_url(surl)

--	if standby then
--		cst_debug(0, "standby="..standby)
--
--		-- wakeup from standby
--		if string.find(standby,"on") then
--			cst_read_url(surl.."?off&cec=off")
--		end
--	end
--	-- zap to channel
--	cst_zapto(baseurl,id)

	if not cst_test then
		plugin_sendurl(cst_url,cst_url,range)
	end
end

if cst_test then
cst_updatefeed("172.16.1.20","tank")
-- cst_updatefeed("172.16.1.10","tank")
-- cst_sendurl("http://172.16.1.20:31339/id=c1f000010070277a", 0)
end

if not cst_test then
plugins['coolstream']={}
plugins.coolstream.name="CoolStream"
plugins.coolstream.desc="IP address (example: <i>192.168.0.1</i>)"
plugins.coolstream.updatefeed=cst_updatefeed
plugins.coolstream.sendurl=cst_sendurl
end
