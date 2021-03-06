--[[
LuCI - Lua Configuration Interface
Copyright 2021 Oskari Rauta <https://github.com/oskarirauta/lucipodman>
]]--

local podman = require "luci.model.podman"
local dk = podman.new()

local containers, images, res
local m, s, o

res = dk.images:list()
if res.code < 300 then
	images = res.body
else
	return
end

res = dk.containers:list({
	query = {
		all=true
	}
})
if res.code < 300 then
	containers = res.body
else
	return
end

function get_images()
	local data = {}

	for i, v in ipairs(images) do
		local index = v.Created .. v.Id

		data[index]={}
		data[index]["_selected"] = 0
		data[index]["id"] = v.Id:sub(8)
		data[index]["_id"] = '<a href="javascript:new_tag(\''..v.Id:sub(8,20)..'\')" class="podman-link" title="'..translate("New tag")..'">' .. v.Id:sub(8,20) .. '</a>'

		if v.RepoTags and next(v.RepoTags)~=nil then
			for i, v1 in ipairs(v.RepoTags) do
				data[index]["_tags"] =(data[index]["_tags"] and ( data[index]["_tags"] .. "<br>" )or "") .. ((v1:match("<none>") or (#v.RepoTags == 1)) and v1 or ('<a href="javascript:un_tag(\''..v1..'\')" class="podman_link" title="'..translate("Remove tag")..'" >' .. v1 .. '</a>'))

				if not data[index]["tag"] then
					data[index]["tag"] = v1
				end
			end
		else
			data[index]["_tags"] = v.RepoDigests[1] and v.RepoDigests[1]:match("^(.-)@.+")
			data[index]["_tags"] = (data[index]["_tags"] and data[index]["_tags"] or  "<none>" ).. ":<none>"
		end

		data[index]["_tags"] = data[index]["_tags"]:gsub("<none>","&lt;none&gt;")
		for ci,cv in ipairs(containers) do
			if v.Id == cv.ImageID then
				data[index]["_containers"] = (data[index]["_containers"] and (data[index]["_containers"] .. " | ") or "")..
				'<a href='..luci.dispatcher.build_url("admin/podman/container/"..cv.Id)..' class="podman_link" title="'..translate("Container detail")..'">'.. cv.Names[1]:sub(1).."</a>"
			end
		end

		data[index]["_size"] = string.format("%.2f", tostring(v.Size/1024/1024)).."MB"
		data[index]["_created"] = os.date("%Y/%m/%d %H:%M:%S",v.Created)
	end

	return data
end

local image_list = get_images()

m = SimpleForm("podman", translate("Podman"))
m.submit=false
m.reset=false

local pull_value={
	_image_tag_name="",
	_registry="index.docker.io"
}

s = m:section(SimpleSection, translate("Pull Image"))
s.template="cbi/nullsection"

o = s:option(Value, "_image_tag_name")
o.template = "podman/cbi/inlinevalue"
o.placeholder="lisaac/luci:latest"
o.write = function(self, section, value)
	local hastag = value:find(":")

	if not hastag then
		value = value .. ":latest"
	end
	pull_value["_image_tag_name"] = value
end

o = s:option(Button, "_pull")
o.inputtitle= translate("Pull")
o.template = "podman/cbi/inlinebutton"
o.inputstyle = "add"
o.write = function(self, section)
	local tag = pull_value["_image_tag_name"]
	local json_stringify = luci.jsonc and luci.jsonc.stringify

	if tag and tag ~= "" then
		podman:write_status("Images: " .. "pulling" .. " " .. tag .. "...\n")
		local res = dk.images:create({query = {fromImage=tag}}, podman.pull_image_show_status_cb)

		if res and res.code == 200 and (res.body[#res.body] and not res.body[#res.body].error and res.body[#res.body].status and (res.body[#res.body].status == "Status: Downloaded newer image for ".. tag)) then
			podman:clear_status()
		else
			podman:append_status("code:" .. res.code.." ".. (res.body[#res.body] and res.body[#res.body].error or (res.body.message or res.message)).. "\n")
		end
	else
		podman:append_status("code: 400 please input the name of image name!")
	end

	luci.http.redirect(luci.dispatcher.build_url("admin/podman/images"))
end

s = m:section(SimpleSection, translate("Import Images"))

o = s:option(DummyValue, "_image_import")
o.template = "podman/images_import"

s = m:section(Table, image_list, translate("Images"))

o = s:option(Flag, "_selected","")
o.disabled = 0
o.enabled = 1
o.default = 0
o.write = function(self, section, value)
	image_list[section]._selected = value
end

o = s:option(DummyValue, "_tags", translate("RepoTags"))
o.rawhtml = true

o = s:option(DummyValue, "_containers", translate("Containers"))
o.rawhtml = true

o = s:option(DummyValue, "_size", translate("Size"))

o = s:option(DummyValue, "_created", translate("Created"))

o = s:option(DummyValue, "_id", translate("ID"))
o.rawhtml = true

local remove_action = function(force)
	local image_selected = {}

	for k in pairs(image_list) do
		if image_list[k]._selected == 1 then
			image_selected[#image_selected+1] = (image_list[k]["_tags"]:match("<br>") or image_list[k]["_tags"]:match("&lt;none&gt;")) and image_list[k].id or image_list[k].tag
		end
	end

	if next(image_selected) ~= nil then
		local success = true

		podman:clear_status()
		for _, img in ipairs(image_selected) do
			local query
			podman:append_status("Images: " .. "remove" .. " " .. img .. "...")

			if force then
				query = {force = true}
			end

			local msg = dk.images:remove({
				id = img,
				query = query
			})
			if msg.code ~= 200 then
				podman:append_status("code:" .. msg.code.." ".. (msg.body.message and msg.body.message or msg.message).. "\n")
				success = false
			else
				podman:append_status("done\n")
			end
		end

		if success then
			podman:clear_status()
		end

		luci.http.redirect(luci.dispatcher.build_url("admin/podman/images"))
	end
end

s = m:section(SimpleSection)
s.template = "podman/apply_widget"
s.err = podman:read_status()
s.err = s.err and s.err:gsub("\n","<br>"):gsub(" ","&nbsp;")
if s.err then
	podman:clear_status()
end

s = m:section(Table,{{}})
s.notitle=true
s.rowcolors=false
s.template="cbi/nullsection"

o = s:option(Button, "remove")
o.inputtitle= translate("Remove")
o.template = "podman/cbi/inlinebutton"
o.inputstyle = "remove"
o.forcewrite = true
o.write = function(self, section)
	remove_action()
end

o = s:option(Button, "forceremove")
o.inputtitle= translate("Force Remove")
o.template = "podman/cbi/inlinebutton"
o.inputstyle = "remove"
o.forcewrite = true
o.write = function(self, section)
	remove_action(true)
end

o = s:option(Button, "save")
o.inputtitle= translate("Save")
o.template = "podman/cbi/inlinebutton"
o.inputstyle = "edit"
o.forcewrite = true
o.write = function (self, section)
	local image_selected = {}

	for k in pairs(image_list) do
		if image_list[k]._selected == 1 then
			image_selected[#image_selected + 1] = image_list[k].id
		end
	end

	if next(image_selected) ~= nil then
		local names, first

		for _, img in ipairs(image_selected) do
			names = names and (names .. "&names=".. img) or img
		end

		local cb = function(res, chunk)
			if res.code == 200 then
				if not first then
					first = true
					luci.http.header('Content-Disposition', 'inline; filename="images.tar"')
					luci.http.header('Content-Type', 'application\/x-tar')
				end
				luci.ltn12.pump.all(chunk, luci.http.write)
			else
				if not first then
					first = true
					luci.http.prepare_content("text/plain")
				end
				luci.ltn12.pump.all(chunk, luci.http.write)
			end
		end

		podman:write_status("Images: " .. "save" .. " " .. table.concat(image_selected, "\n") .. "...")
		local msg = dk.images:get({query = {names = names}}, cb)

		if msg.code ~= 200 then
			podman:append_status("code:" .. msg.code.." ".. (msg.body.message and msg.body.message or msg.message).. "\n")
			success = false
		else
			podman:clear_status()
		end
	end
end

o = s:option(Button, "load")
o.inputtitle= translate("Load")
o.template = "podman/images_load"
o.inputstyle = "add"

return m
