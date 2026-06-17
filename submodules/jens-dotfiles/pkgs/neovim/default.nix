{ pkgs, extraRC ? "", extraStartPlugins ? [], extraOptPlugins ? [] }:

pkgs.neovim.override {
  configure = {
    customRC = ''
      " Configure ' ' as the leader key (would be '\' by default).
      let mapleader = " "

      " inoremap fd <Esc>
      " vnoremap fd <Esc>

      " Configure colorscheme
      let g:gruvbox_contrast_dark='hard'
      let g:gruvbox_contrast_light='hard'
      colorscheme gruvbox
      "hi ColorMagenta guifg='#f92672' guibg=132 guibg='NONE' ctermbg='NONE' gui='NONE' cterm='NONE'
      "hi! link haskellOperators ColorMagenta

      set termguicolors

      " Enable line numbers
      set number
      "set relativenumber

      " Highlight active line (this works well with gruvbox)
      set cursorline

      " Use 2 spaces for indentation
      set shiftwidth=2
      set expandtab
      set shiftround

      " Send the active buffer to the background when opening a file (allows to have unsaved changes in multiple files)
      set hidden

      set smartindent
      filetype plugin indent on

      " Search case-insensitive by default but switch to case-sensitive when using uppercase letters.
      set ignorecase
      set smartcase

      " Full mouse support
      set mouse=a

      " Yank to primary selection.
      " I want to use clipboard=autoselect, when it is implemented: https://github.com/neovim/neovim/pull/3708
      set clipboard=unnamed

      " Wrap at word boundaries instead of splitting words at the end of the line.
      set linebreak

      " Set colorcolumn to nudge me to stay below 120 characters per line
      set colorcolumn=121

      " Shows the effects of a command incrementally, as you type. Also shows partial off-screen results in a preview window.
      set inccommand=split

      " Configure completion: First <tab> completes to the longest common string and also opens the completion menu, following <Tab>s complete the next matches.
      set wildmode=longest:full,full

      " Don't show mode in command line (command line is used by echodoc.vim instead while mode is shown in status bar)
      set noshowmode

      " Disable preview *window* on completion
      set completeopt-=preview


      " Save with Ctrl-S (if file has changed)
      nnoremap <C-s> <Cmd>update<CR>

      nnoremap <C-p> <Cmd>Files<CR>

      " Use `ALT+{h,j,k,l}` to navigate windows from any mode
      tnoremap <A-h> <C-\><C-N><C-w>h
      tnoremap <A-j> <C-\><C-N><C-w>j
      tnoremap <A-k> <C-\><C-N><C-w>k
      tnoremap <A-l> <C-\><C-N><C-w>l
      inoremap <A-h> <C-\><C-N><C-w>h
      inoremap <A-j> <C-\><C-N><C-w>j
      inoremap <A-k> <C-\><C-N><C-w>k
      inoremap <A-l> <C-\><C-N><C-w>l
      nnoremap <A-h> <C-w>h
      nnoremap <A-j> <C-w>j
      nnoremap <A-k> <C-w>k
      nnoremap <A-l> <C-w>l

      " NERDTree
      " Show hidden files by default
      let g:NERDTreeShowHidden = 1
      " Automaticaly close nvim if NERDTree is only thing left open
      autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
      " Toggle with Alt-b
      nnoremap <a-b> <Cmd>NERDTreeToggle<CR>

      " Airline
      let g:airline#extensions#tabline#enabled = 1

      let g:highlightedyank_highlight_duration = 200

      filetype on

      " Load filetype plugins
      "autocmd FileType nix :packadd vim-nix

      " Bufferline
      " Bufferline is integrated into airline, so also showing buffers in the command bar is not desirable.
      let g:bufferline_echo = 0


      " Old language client keybindings
      "  nnoremap <Leader>la <Cmd>call LanguageClient_workspace_applyEdit()<CR>
      "  nnoremap <Leader>lc <Cmd>call LanguageClient#textDocument_definition()<CR>
      "  nnoremap <Leader>ld <Cmd>call LanguageClient#textDocument_definition()<CR>
      "  nnoremap <Leader>le <Cmd>call LanguageClient#explainErrorAtPoint()<CR>
      "  nnoremap <Leader>lf <Cmd>call LanguageClient#textDocument_formatting()<CR>
      "  nnoremap <Leader>lh <Cmd>call LanguageClient#textDocument_hover()<CR>
      "  nnoremap <Leader>lm <Cmd>call LanguageClient_contextMenu()<CR>
      "  nnoremap <Leader>lr <Cmd>call LanguageClient#textDocument_rename()<CR>
      "  nnoremap <Leader>ls <Cmd>call LanguageClient_textDocument_documentSymbol()<CR>
      "  nnoremap <Leader>lt <Cmd>call LanguageClient#textDocument_typeDefinition()<CR>
      "  nnoremap <Leader>lx <Cmd>call LanguageClient#textDocument_references()<CR>
      "  nnoremap <Leader>lq <Cmd>LanguageClientStop<CR><Cmd>LanguageClientStart<CR>


      " Use deoplete for autocompletion.
      let g:deoplete#enable_at_startup = 1

      nnoremap <Leader>go <Cmd>Goyo<CR>

      " <Leader>n clears the last search highlighting.
      nnoremap <Leader>n <Cmd>nohlsearch<CR>
      vnoremap <Leader>n <Cmd>nohlsearch<CR>

      " Shortcut to enable spellcheck (requires aspell installation)
      nnoremap <Leader>s <Cmd>setlocal spell spelllang=en_us<CR>
      nnoremap <Leader>S <Cmd>setlocal spell spelllang=de_de<CR>

      lua << EOF
        local nvim_lsp = require('lspconfig')

        local on_attach = function(client, bufnr)
          local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
          local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

          -- Enable completion triggered by <c-x><c-o>
          buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

          -- Mappings.
          local opts = { noremap=true, silent=true }

          -- See `:help vim.lsp.*` for documentation on any of the below functions
          buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
          buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
          buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
          buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
          buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
          buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
          buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
          buf_set_keymap('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
          buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
          buf_set_keymap('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
          buf_set_keymap('n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
          buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
          buf_set_keymap('n', '<space>e', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
          buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
          buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
          buf_set_keymap('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
          buf_set_keymap('n', '<space>f', '<cmd>lua vim.lsp.buf.formatting()<CR>', opts)
        end

        nvim_lsp.clangd.setup {
          on_attach = on_attach
        }
        nvim_lsp.hls.setup  {
          on_attach = on_attach
        }
        nvim_lsp.gdscript.setup {
          on_attach = on_attach
        }
      EOF

      ${extraRC}
    '';
    packages.myVimPackage = with pkgs.vimPlugins; {
      start = [
        # Colorscheme
        gruvbox-community

        # Distraction-free writing in Vim.
        goyo-vim

        # Basics (VSCodeVim compatible)
        # Changes 's<char><char>' to motion that finds the next combination of the given characters (similar to 'f<char>')
        vim-sneak
        # Various commands that add, change and remove brackets, quotes and tags.
        vim-surround
        # Jump to any location by showing helper marks.
        vim-easymotion

        # Provides hook that allows other plugins to register repeat actions ('.')
        vim-repeat
        # Increment and decrement dates and times with <Ctrl-A> and <Ctrl-X>
        vim-speeddating

        # Mark whitespace red
        vim-better-whitespace

        # Multi-cursor. <C-n> to start/add cursor on next match, <C-x> to skip match, <C-p> to undo cursor, <A-n> to select all matches.
        vim-multiple-cursors

        fzfWrapper
        fzf-vim

        # neovim native language server support
        nvim-lspconfig
        deoplete-nvim

        nvim-gdb

        vim-highlightedyank
        #vim-numbertoggle

        # A Vim plugin which shows a git diff in the 'gutter' (sign column).
        vim-gitgutter

        # NERDTree
        nerdtree

        # Better status bar
        vim-airline
        vim-bufferline

        # Nix syntax highlighting
        vim-nix

        # Haskell syntax highlighting
        haskell-vim
      ] ++ extraStartPlugins;
      opt = [
      ] ++ extraOptPlugins;
    };
  };
}
