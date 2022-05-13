# oscillator

Vim/Neovim plugin to access the system clipboard using OSC52 escape sequences.
It provides both, yanking to and pasting from the clipboard. Neovim needs a
small patch (against release version 0.7, but should work with nightly also) to
make pasting from clipboard work. The patch is supplied in this repository
(nvim.patch).

## Configuration

Sample vimrc entries to configure oscillator and enable transparent clipboard
access for neovim.

    " let g:oscillator_silent = v:true
    " let g:oscillator_yank_limit = 1000000
    " let g:oscillator_base64decoder = 'base64 -d'
    " let g:oscillator_base64encoder = 'base64'
    if has('nvim')
      let g:clipboard = {
        \ 'name': 'oscillator',
        \ 'copy': {
        \     '+': {lines, regtype -> OscillatorWriteRegToClipboard(lines, regtype, 'clipboard')},
        \     '*': {lines, regtype -> OscillatorWriteRegToClipboard(lines, regtype, 'primary')},
        \     },
        \ 'paste': {
        \     '+': {-> OscillatorReadRegFromClipboard('clipboard')},
        \     '*': {-> OscillatorReadRegFromClipboard('primary')},
        \     },
        \ }
    else
      vnoremap <leader>y :OscillatorYank<CR>
      nnoremap <leader>p :OscillatorPaste<CR>
    endif

## Related projects

- [OSCYank](https://github.com/ojroques/vim-oscyank)
- [Vital](https://github.com/vim-jp/vital.vim)
