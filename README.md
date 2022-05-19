# Oscillator

## Introduction

Oscillator is a neovim / vim plugin to allow full access to the system
clipboard in any environment. No additional requirements are needed, just set
up your terminal emulator once to allow OSC52 terminal sequences and your done.
This also works when running vim on a remote machine through ssh or in a
virtual environment, e.g. docker. The clipboard contents is sent through stdin
/ stdout, just the same way as the normal communication between vim and the
terminal emulator. While there are other solutions for yanking contents from
vim to the system clipboard (see related work) they are lacking the
other direction to paste the clipboard to vim.

## Installation

Copy the plugin folder (or git-clone it directly) to an appropriate place in
your vim directory so that the built-in vim plugin manager can find it.
For example:

    $ mkdir -p ~/.vim/pack/plugins/start
    $ cd ~/.vim/pack/plugins/start
    $ git clone https://github.com/captaingroove/oscillator.git

## Configuration

Neovim can be configured to handle clipboard access fully transparently using
the + and * registers by putting this in you neovim config file:

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

For vim you can simply add two commands for yanking and pasting:

    vnoremap <leader>y :OscillatorYank<CR>
    nnoremap <leader>p :OscillatorPaste<CR>

That's it.

There are some optional settings:

    let g:oscillator_silent = v:true
    " v:false - surpress messages (default)
    " v:true  - be more verbose

    let g:oscillator_yank_limit = 1000000
    " Limit the size of text in bytes that can be yanked to the clipboard.
    " Default is 0 which means no limit.

    let g:oscillator_base64decoder = 'base64 -d'
    " Use this shell command to decode the clipboard text to base64. Default is a
    " vimscript implementation of the base64 algorithm. This applies only to vim.
    " For neovim a lua implementation is used.
    " Default is '' which means use the plugin internal decoder.

    let g:oscillator_base64encoder = 'base64'
    " Use this shell command to encode the clipboard text to base64. Default is a
    " vimscript implementation of the base64 algorithm. This applies only to vim.
    " For neovim a lua implementation is used.
    " Default is '' which means use the plugin internal encoder.

    let g:oscillator_osc52_default_selection = 'clipboard'
    " Type of clipboard that is used by the OscillatorYank and OscillatorPaste
    " ex-commands. If set to a different value, the 'primary' selection is used.
    " 'clipboard' and 'primary' are clipboard types defined by the OSC52
    " documentation, see also https://www.xfree86.org/current/ctlseqs.html.
    " Default is 'clipboard' which corresponds to the cut&paste clipboard on
    " most platforms.

## Compatibility

The plugin has been tested on Linux with the following vim versions:

- vim 8.2
- neovim v0.7.1-dev+33-g35075dcc2-dirty with nvim.path from this repo applied

... and with the following terminal emulators:

- kitty 0.24.4. Add the following lines to with kitty.conf to allow OSC52
  terminal sequences with no size limits for the clipboard text:

    clipboard_control write-clipboard write-primary read-clipboard read-primary
    clipboard_max_size 0

## Caveats

- The plugin works with vim out of the box, however a small patch is required for
  neovim. The patch is supplied in this repo (vim.patch). You can apply it to
  the neovim source code with the following command from the root of the source
  tree:

    $ git apply vim.patch

  The upside is that the plugin is much faster with neovim than with vim due to
  lua instead of vimscript. The plugin provides implemenation of the same
  functionality in both, lua and vimscript.

- When working remotely and also using a terminal multiplexer like tmux or any
  other program that modifies stdin / stdout the OSC52 sequences might be
  filtered out.

## Related work

- Yanking to the clipboard using OSC52 terminal sequences: [OSCYank](https://github.com/ojroques/vim-oscyank)
- Base64 encoding / decoding in vimscript: [Vital](https://github.com/vim-jp/vital.vim)
