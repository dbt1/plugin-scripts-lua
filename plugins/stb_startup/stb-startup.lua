-- The Tuxbox Copyright
--
-- Copyright 2018 Markus Volk, Sven Hoefer, Don de Deckelwech
--
-- Redistribution and use in source and binary forms, with or without modification, 
-- are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice, this list
-- of conditions and the following disclaimer. Redistributions in binary form must
-- reproduce the above copyright notice, this list of conditions and the following
-- disclaimer in the documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS`` AND ANY EXPRESS OR IMPLIED
-- WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
-- AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
-- HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
-- EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- The views and conclusions contained in the software and documentation are those of the
-- authors and should not be interpreted as representing official policies, either expressed
-- or implied, of the Tuxbox Project.

caption = "STB-Startup"

n = neutrino()
fh = filehelpers.new()

devbase = "/dev/mmcblk0p"
bootfile = "/boot/STARTUP"
bootfile_select = "/boot/STARTUP_"
inode_empty = "51296"

locale = {}
locale["deutsch"] = {
	current_boot_partition = "Die aktuelle Startpartition ist: ",
	choose_partition = "\n\nBitte wählen Sie die neue Startpartition aus",
	start_partition = "Rebooten und die gewählte Partition starten?",
	empty_partition = "Die gewählte Partition ist leer"
}
locale["english"] = {
	current_boot_partition = "The current start partition is: ",
	choose_partition = "\n\nPlease choose the new start partition",
	start_partition = "Reboot and start the chosen partition?",
	empty_partition = "The selected partition is empty"
}

function sleep (a) 
    local sec = tonumber(os.clock() + a); 
    while (os.clock() < sec) do 
    end 
end

function reboot()
       	local file = assert(io.popen("which systemctl >> /dev/null"))
       	running_init = file:read('*line')
       	file:close()
	if running_init == "/bin/systemctl" then
		local file = assert(io.popen("systemctl reboot"))
	else
                local file = assert(io.popen("reboot"))
 	end
end

neutrino_conf = configfile.new()
neutrino_conf:loadConfig("/var/tuxbox/config/neutrino.conf")
lang = neutrino_conf:getString("language", "english")
if locale[lang] == nil then
	lang = "english"
end
timing_menu = neutrino_conf:getString("timing.menu", "0")

for line in io.lines(bootfile) do
	akt_boot_partition = string.sub(line,23,23)
end

chooser_dx = n:scale2Res(600)
chooser_dy = n:scale2Res(200)
chooser_x = SCREEN.OFF_X + (((SCREEN.END_X - SCREEN.OFF_X) - chooser_dx) / 2)
chooser_y = SCREEN.OFF_Y + (((SCREEN.END_Y - SCREEN.OFF_Y) - chooser_dy) / 2)

chooser = cwindow.new {
	x = chooser_x,
	y = chooser_y,
	dx = chooser_dx,
	dy = chooser_dy,
	title = caption,
	icon = "settings",
	has_shadow = true,
	btnRed = "Partition 1",
	btnGreen = "Partition 2",
	btnYellow = "Partition 3",
	btnBlue = "Partition 4"
}
chooser_text = ctext.new {
	parent = chooser,
	x = OFFSET.INNER_MID,
	y = OFFSET.INNER_SMALL,
	dx = chooser_dx - 2*OFFSET.INNER_MID,
	dy = chooser_dy - chooser:headerHeight() - chooser:footerHeight() - 2*OFFSET.INNER_SMALL,
	text = locale[lang].current_boot_partition .. akt_boot_partition .. locale[lang].choose_partition,
	font_text = FONT.MENU,
	mode = "ALIGN_CENTER"
}
chooser:paint()

i = 0
d = 500 -- ms
t = (timing_menu * 1000) / d
if t == 0 then
	t = -1 -- no timeout
end

colorkey = nil
repeat
	i = i + 1
	msg, data = n:GetInput(d)
	if (msg == RC['red']) then
		start = "1"
		root = "3"
		colorkey = true
	elseif (msg == RC['green']) then
		start = "2"
		root = "5"
		colorkey = true
	elseif (msg == RC['yellow']) then
		start = "3"
		root = "7"
		colorkey = true
	elseif (msg == RC['blue']) then
		start = "4"
		root = "9"
		colorkey = true
	end
until msg == RC['home'] or colorkey or i == t

chooser:hide()

if colorkey then
        local file = assert(io.popen("tune2fs -l " .. devbase .. root .. " | grep 'Inode count' | grep '" .. inode_empty .. "' | awk -F ' ' '{print $3}'"))
        local dest_output = file:read('*line')
        file:close()
        if inode_empty == dest_output then
                local ret = hintbox.new { title = caption, icon = "settings", text = locale[lang].empty_partition };
                ret:paint();
                sleep(3)
                return
        else
               	fh:cp(bootfile_select .. start, bootfile, "f")
		res = messagebox.exec {
			title = caption,
			icon = "settings",
			text = locale[lang].start_partition,
			timeout = 0,
			buttons={ "yes", "no" }
		}

	end
end

if res == "yes" then
	reboot()
end

return
