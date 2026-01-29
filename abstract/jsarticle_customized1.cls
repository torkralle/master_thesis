\ProvidesClass{jsarticle_customized1}[]%
%
\LoadClassWithOptions{jsarticle}
%
%  title page setting
%   maketile parameter : title, author, authorinfo, subtitle
%
%
%用紙サイズの調整
\setlength{\textheight}{265mm}
\setlength{\textwidth}{170mm}
\setlength{\unitlength}{1mm}
\addtolength{\topmargin}{-25mm}
\setlength{\oddsidemargin}{-5.4mm}
\setlength{\evensidemargin}{-10.4mm}

\pagestyle{empty}
%\maketitleコマンドの調整
\def\labname#1{\gdef\@labname{#1}}
\def\maketitle{
\begin{center}
\begin{tabular}{|l|c|c|} \hline
\makebox[54mm]{\bf 修士論文提出者氏名} &
\makebox[48mm]{\bf \@author} &
\makebox[54mm]{\bf \@labname}\\ \hline
\multicolumn{3}{|l|}{\rule{8mm}{0mm}{\bf 修士論文題名}}\\
\multicolumn{3}{|c|}{ {\large {\bf \@title}}}\\
\hline
\end{tabular}
\end{center}
}

