"TODO: get path to work (i.e., to stick -- it gets trashed when switching
"buffers)
set path+=src
set path+=src/**

"TODO: get taglist working
"	noremap! <C-W><C-b> TlistOpen
"	set g:proj_flags = "imstF"
"	set Tlist_WinHeight = ''
"		this only works b/c I hacked taglist to do below rather than belowright
"		might be easier just to set it to belowleft or actually patch taglist to
"		make this configurable
"	set Tlist_Use_Horiz_window = 1
"
"		this seems to be what causes the fold refresh bug on tabswitch
"	set Tlist_Show_One_file = 1
" Open project
Project ./.vimproject
tabdo Project
tabdo foldopen!

" Full screen (as best we can)
winpos 0 0
set lines=61 columns=238
