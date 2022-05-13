-- Copyright (c) 2022 Jörg Bakker
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the 'Software'), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local base64 = require('base64')

function oscillator_write_to_clipboard(clipboard_type, str)
    local stderr = io.open("/dev/fd/2", "w")
    str_encoded = base64.encode(str)
    stderr:write('\027]52;' .. clipboard_type .. ';' .. str_encoded .. '\007')
    stderr:flush()
    stderr:close()
end

function oscillator_read_from_clipboard(clipboard_type)
    vim.api.nvim_ui_terminput_stop()
    ret = ''
    semicolon_skip_count = 2
    local stderr = io.open("/dev/fd/2", "w")
    local stdin = io.open("/dev/fd/0", "r")
    stderr:write('\027]52;' .. clipboard_type .. ';?\007')
    stderr:flush()
    while true do
        char = stdin:read(1)
        if not char then
            break
        end
        if semicolon_skip_count > 0 then
            if char == ';' then
                semicolon_skip_count = semicolon_skip_count - 1
            end
        else
            if char == '\027' then
                char = stdin:read(1)
                if not char or char == '\\' then
                    break
                end
            end
            ret = ret .. char
        end
    end
    stderr:close()
    stdin:close()
    vim.api.nvim_ui_terminput_start()
    return base64.decode(ret)
end
