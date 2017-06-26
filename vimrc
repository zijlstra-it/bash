" Parts taken from https://github.com/sole/dotvim/blob/master/vimrc
set showcmd
set autoindent
set hlsearch
set showmatch

" SET COLOR SCHEME
":colorscheme sole

" ENABLE PLUGINS IF INSTALLED
filetype plugin on

" ENABLE SYNTAX HIGHLIGHT
syntax enable
:highlight Search ctermfg=black ctermbg=yellow

" SPACES & TABS
" Explanations from http://tedlogan.com/techblog3.html
set tabstop=4     " How many columns a tab counts for
set softtabstop=2 " How many columns vim uses when pressing TAB in insert mode
set shiftwidth=2  " How many columns text is indented with << and >>
