#!/usr/bin/env perl

# ====================
# LaTeX Engine Settings
# ====================
# LuaLaTeX を使用（lualatexコマンドを使用）
$lualatex = 'lualatex -synctex=1 -halt-on-error -file-line-error -interaction=nonstopmode %O %S';
$max_repeat = 10;

# PDF モードを LuaLaTeX に設定
$pdf_mode = 4;

# Build artifacts go under ./out so cross-references stabilize across runs.
$out_dir = 'out';

# ====================
# Bibliography Settings
# ====================
# LuaLaTeX では bibtex ではなく biber または upbibtex を使用
$bibtex = 'upbibtex %O %S';
$biber = 'biber --bblencoding=utf8 -u -U --output_safechars %O %S';

# ====================
# Index Settings
# ====================
$makeindex = 'mendex %O -o %D %S';

# ====================
# Environment Variables
# ====================
$ENV{'TZ'} = 'Asia/Tokyo';
$ENV{OPENTYPEFONTS} = '/usr/share/fonts//:';
$ENV{TTFONTS} = '/usr/share/fonts//:';
$ENV{'TEXMFVAR'} = "$out_dir/texmf-var";
$ENV{'TEXMFCACHE'} = "$out_dir/texmf-cache";

# ====================
# Preview Settings
# ====================
$pvc_view_file_via_temporary = 0;

if ($^O eq 'linux') {
    $pdf_previewer = "xdg-open %S";
} elsif ($^O eq 'darwin') {
    $pdf_previewer = "open %S";
} else {
    $pdf_previewer = "start %S";
}

# ====================
# Clean Up Settings
# ====================
$clean_full_ext = "%R.synctex.gz";
