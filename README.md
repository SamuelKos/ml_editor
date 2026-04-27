# ML-editor
GUI-editor for Tcl development. Intendet target system is, real hardware running Windows95, but it
should work in any platform with Tcl/Tk 8.4 or better.

![editor_windows](pics/mlpic256.bmp)

# Featuring
- Auto-indent
- Comment/Uncomment
- Syntax highlight
- Procedure window
- Right click on a word to have word copied to find-window
- Editor can be invoked with file names on the command line, including wildcards
- Brace matching - highlight matching braces, also quotes and square brackets
- Find in files


# Launching
In ml-directory, enter either:
- tclsh main.tcl
- wish main.tcl


And it should launch. Font can currently be changed only manually by editing configuration file.
Edit it after first exit. Tcl/Tk can be getted from [here](https://www.bawt.tcl3d.org/download.html#tclpure)

If can install from app repository or compile, do so.


# Notes
In picture is non-monotype font in use, which gives it nice looks, since punctuation and braces takes much
less space "faded away". But in practice, monotype font like Courier is in effect mandatory.


