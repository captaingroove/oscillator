" Copyright (c) 2022 Jörg Bakker
"
" Permission is hereby granted, free of charge, to any person obtaining a copy of
" this software and associated documentation files (the 'Software'), to deal in
" the Software without restriction, including without limitation the rights to
" use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
" of the Software, and to permit persons to whom the Software is furnished to do
" so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in all
" copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
" SOFTWARE.

if exists('g:oscillator_loaded') || &compatible
  echom 'oscillator already loaded or vim compatible mode is on'
  finish
endif
let g:oscillator_loaded = 1

if has('nvim')
  lua require('oscillator')
endif

let s:silent = get(g:, 'oscillator_silent', v:true)
let s:yank_limit = get(g:, 'oscillator_yank_limit', 0)
let s:base64decoder = get(g:, 'oscillator_base64decoder', '')
let s:base64encoder = get(g:, 'oscillator_base64encoder', '')
let s:osc52_default_selection = get(g:, 'oscillator_osc52_default_selection', 'clipboard') ? 'c' : 'p'

function! s:warn(msg)
  echohl WarningMsg
  echo msg
  echohl None
endfunction

function! OscillatorWriteStrToClipboard(str, clipboard_type)
  let length = strlen(a:str)
  if s:yank_limit > 0 && length > s:yank_limit
    call s:warn('[oscillator] selection has length ' . length . ', limit is ' . s:yank_limit)
    return
  endif
  if has('nvim')
    call luaeval("oscillator_write_to_clipboard(_A, '" . a:clipboard_type . "')", a:str)
  else
    if strlen(s:base64encoder)
      let str_encoded = system('echo ' . a:str . ' | ' . s:base64encoder)
    else
      let str_encoded = s:b64encode(a:str, 0)
    endif
    let request = "\e]52;" . a:clipboard_type . ";" . str_encoded . "\x07"
    call s:raw_echo(request)
  endif
  if !s:silent
    echom '[oscillator] ' . length . ' characters written to clipboard'
  endif
endfunction

function! OscillatorReadStrFromClipboard(clipboard_type)
  if has('nvim')
    let str_decoded = luaeval("oscillator_read_from_clipboard('" . a:clipboard_type . "')")
  else
    let response = ''
    let request = "\e]52;" . a:clipboard_type . ";?\x07"
    call s:raw_echo(request)
    let semicolon_skip_count = 2
    while 1
      let char = getchar()
      if semicolon_skip_count > 0
        if char == 59
          let semicolon_skip_count -= 1
        endif
      else
        "TODO is the end of OSC52 escape sequence always '\e\\' ?
        if char == 27
          let char = getchar()
          if char == 92
            break
          endif
        endif
        let response .= nr2char(char)
      endif
    endwhile
    if strlen(s:base64decoder)
      let str_decoded = system('echo ' . response . ' | ' . s:base64decoder)
    else
      let str_decoded = s:b64decode(response)
    endif
  endif
  if !s:silent
    echom "[oscillator] " . strlen(str_decoded) . " characters read from clipboard"
  endif
  return str_decoded
endfunction

function! OscillatorWriteRegToClipboard(lines, regtype, clipboard_type)
  let str = ''
  " TODO handle all register types like 'c' characterwise text, 'l'
  " linewise text, 'b' blockwise text, like column "Type" in the register
  " listing or 'v', 'V', ... properly (-> help regtype)
  if (a:regtype == 'l' || a:regtype == 'V')
    let str = join(a:lines, "\n")
  elseif (a:regtype == 'c' || a:regtype == 'v')
    let str = a:lines[0]
  endif
  call OscillatorWriteStrToClipboard(str, a:clipboard_type)
endfunction

function! OscillatorReadRegFromClipboard(clipboard_type)
  let str = OscillatorReadStrFromClipboard(a:clipboard_type)
  let lines = split(str, "\n")
  if len(lines) == 1
    return [lines, 'c']
  else
    return [lines, 'l']
  endif
endfunction

" Paste clipboard to current position in buffer
function! OscillatorPaste()
  " TODO leave a choice which clipboard_type to read from when pasting
  " directly into the buffer, without using registers?
  let str = OscillatorReadStrFromClipboard(s:osc52_default_selection)
  exe "normal! a" . str . "\<Esc>"
endfunction

" Send the visual selection to the terminal's clipboard
function! OscillatorYankVisual() range
  let [line_start, column_start] = getpos("'<")[1:2]
  let [line_end, column_end] = getpos("'>")[1:2]
  let lines = getline(line_start, line_end)
  if len(lines) == 0
    return
  endif
  let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
  let lines[0] = lines[0][column_start - 1:]
  " TODO leave a choice which clipboard_type to write to when yanking
  " directly from the buffer to the clipboard, without using registers?
  call OscillatorWriteStrToClipboard(join(lines, "\n"), s:osc52_default_selection)
  execute "normal! `<"
endfunction

command! -range OscillatorYank <line1>,<line2>call OscillatorYankVisual()
command! -nargs=1 OscillatorYankReg call OscillatorWriteStrToClipboard(getreg(<f-args>))
command! OscillatorPaste call OscillatorPaste()

function! s:raw_echo(str)
  if filewritable('/dev/fd/2')
    call writefile([a:str], '/dev/fd/2', 'b')
  else
    exec("silent! !echo " . shellescape(a:str))
    redraw!
  endif
endfunction

" Encode a string of bytes in base 64.
" If size is > 0 the output will be line wrapped every `size` chars.
function! s:b64encode(str, size)
  let bytes = s:str2bytes(a:str)
  let b64_arr = []

  for i in range(0, len(bytes) - 1, 3)
    let n = bytes[i] * 0x10000
          \ + get(bytes, i + 1, 0) * 0x100
          \ + get(bytes, i + 2, 0)
    call add(b64_arr, s:b64_table[n / 0x40000])
    call add(b64_arr, s:b64_table[n / 0x1000 % 0x40])
    call add(b64_arr, s:b64_table[n / 0x40 % 0x40])
    call add(b64_arr, s:b64_table[n % 0x40])
  endfor

  if len(bytes) % 3 == 1
    let b64_arr[-1] = '='
    let b64_arr[-2] = '='
  endif

  if len(bytes) % 3 == 2
    let b64_arr[-1] = '='
  endif

  let b64 = join(b64_arr, '')
  if a:size <= 0
    return b64
  endif

  let chunked = ''
  while strlen(b64) > 0
    let chunked .= strpart(b64, 0, a:size) . "\n"
    let b64 = strpart(b64, a:size)
  endwhile

  return chunked
endfunction

function! s:str2bytes(str)
  return map(range(len(a:str)), 'char2nr(a:str[v:val])')
endfunction

" Lookup table for s:b64encode.
let s:b64_table = [
      \ "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P",
      \ "Q","R","S","T","U","V","W","X","Y","Z","a","b","c","d","e","f",
      \ "g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v",
      \ "w","x","y","z","0","1","2","3","4","5","6","7","8","9","+","/",
      \ ]

let s:is_padding = 1
let s:padding_symbol = '='
let s:is_padding_symbol = {c -> c == s:padding_symbol}
let s:is_ignore_symbol = {c -> 0}
let s:b64_decode_table = {}
for i in range(len(s:b64_table))
  let s:b64_decode_table[s:b64_table[i]] = i
endfor

function! s:bytes2str(bytes) abort
  return eval('"' . join(map(copy(a:bytes), 'printf(''\x%02x'', v:val)'), '') . '"')
endfunction

function! s:b64decode_algorithm(b64, map, is_padding, padcheck) abort
  let bytes = []
  if len(a:b64) < 2
    " no data
    return bytes
  endif
  for i in range(0, len(a:b64) - 1, 4)
    let pack = repeat([0], 4)
    for j in range(4)
      if (len(a:b64) > (i + j)) && !a:padcheck(a:b64[i + j])
        let pack[j] = a:map[a:b64[i + j]]
      endif
    endfor
    let n = pack[0]   * 0x40000
          \ + pack[1] * 0x1000
          \ + pack[2] * 0x40
          \ + pack[3]
    call add(bytes, n / 0x10000        )
    call add(bytes, n /   0x100 % 0x100)
    call add(bytes, n           % 0x100)
    if !a:is_padding && ((len(a:b64) - 1) <  (i + 4))
      " manual nondata byte cut
      let nulldata = (i + 3) - (len(a:b64) - 1)
      if 1 == nulldata
        unlet bytes[-1]
      elseif 2 == nulldata
        unlet bytes[-1]
        unlet bytes[-1]
      endif
    endif
  endfor
  if a:is_padding
    if a:padcheck(a:b64[-1])
      unlet bytes[-1]
    endif
    if a:padcheck(a:b64[-2])
      unlet bytes[-1]
    endif
  endif
  return bytes
endfunction

function! s:b64decoderaw(data) abort
  return s:b64decode_algorithm(filter(split(a:data, '\zs'), {idx, c -> !s:is_ignore_symbol(c)}),
        \ s:b64_decode_table,
        \ s:is_padding,
        \ s:is_padding_symbol)
endfunction

function! s:b64decode(data) abort
  return s:bytes2str(s:b64decoderaw(a:data))
endfunction
