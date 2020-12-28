{ pkgs, jens-dotfiles, ... }:
{
  #programs.bash.interactiveShellInit = ''
  #  # https://www.reddit.com/r/neovim/comments/6npyjk/neovim_terminal_management_avoiding_nested_neovim/
  #  if [ -n "$NVIM_LISTEN_ADDRESS" ]; then
  #    export VISUAL="nvr -cc tabedit --remote-wait +'set bufhidden=wipe'"
  #  else
  #    export VISUAL="nvim"
  #  fi
  #  EDITOR="$VISUAL"
  #'';

  nixpkgs.overlays = [
    (self: super: {
      neovim = import "${jens-dotfiles}/pkgs/neovim" { pkgs = super; };
    })
    (self: super: {
      neovim = super.neovim.override (old: {
        viAlias = true;
        vimAlias = true;
        configure = old.configure // {
          packages = old.configure.packages // {
            myVimPackage2 = with pkgs.vimPlugins; {
              start = [
                #vim-buffergator
                #(pkgs.vimUtils.buildVimPlugin {
                #  name = "sidepanel.vim";
                #  src = pkgs.fetchFromGitHub {
                #    owner = "miyakogi";
                #    repo = "sidepanel.vim";
                #    rev = "0f8ff34a93cb15633fc0f79ae4ad8892ee772bf4";
                #    sha256 = "0qhhi6mq1llkvpq8j89kvdlfgzrk3vgmhja29r0636g08x6cynkr";
                #  };
                #})
                bufexplorer
                vim-orgmode
                #taglist
                tagbar
              ];
              opt = [
              ];
            };
          };
          customRC = old.configure.customRC + ''
            " set backspace=indent,eol,start

            "FIXME doesn't work
            "nnoremap <SPACE> <Nop>
            "let mapleader = "<SPACE>"

            noremap <SPACE>b <Cmd>Buffers<CR>
            noremap <SPACE>c <Cmd>Commands<CR>
            noremap <SPACE>f <Cmd>Files<CR>

            noremap <c-p> <Cmd>Files<CR>
            "noremap <c-s-p> <Cmd>Commands<CR>
            noremap <c-tab> <Cmd>bn<CR>
            tnoremap fd <C-\><C-n>

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

            "  " Set position (left or right) if neccesary (default: "left").
            "  let g:sidepanel_pos = "left"
            "  " Set width if neccesary (default: 32)
            "  let g:sidepanel_width = 26
            "  
            "  " To use rabbit-ui.vim
            "  "let g:sidepanel_use_rabbit_ui = 1
            "  
            "  " Activate plugins in SidePanel
            "  let g:sidepanel_config = {}
            "  let g:sidepanel_config['nerdtree'] = {}
            "  "let g:sidepanel_config['tagbar'] = {}
            "  "let g:sidepanel_config['gundo'] = {}
            "  let g:sidepanel_config['buffergator'] = {}
            "  "let g:sidepanel_config['vimfiler'] = {}
            "  "let g:sidepanel_config['defx'] = {}

            let g:org_todo_keywords = [['TODO(t)', 'CURRENT(c)', 'DEFER(l)', '|', 'DONE(d)', 'WONTFIX(w)']]
          '';
        };
      });
    })
  ];
}
