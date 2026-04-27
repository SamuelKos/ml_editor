# Structure briefing Begin
# Structure briefing
# Double-click braces
# Syntax highlight
# Proclist window related
# Search related
# Grep search (find in files)
# Goto_line
# To be organised
# Overrides
# File-menu
# Walk_Tabs
# __init__
# __main__
# Structure briefing End

package provide app-ml 1.13

#====================================================================#
# This program uses global array editor() to store editor information
# editor(window_number,window) = frame/window
# editor(window_number,file)	 = file name
# editor(window_number,status)	 = "" or "modified" (or "READ ONLY")
# editor(window_number,procs)   = list of procedure names
# etc. See __main__ for more information
#====================================================================#

#== Double-click braces to select Begin =================#

# Select range of brace, bracket or quote
proc select_block {widget} {
	# Don't accept quoted braces
	set behind [$widget get insert-1chars]
	if {[string equal $behind "\\" ] } {return 0}
	
	set mark [$widget index insert]
	set openingChar [$widget get $mark]
	set opener 1

	# Brace, bracket, quote
	switch $openingChar "\{" {
		set closingChar "\}"
	} "\[" {
		set closingChar "\]"
	} "\}" {
		set closingChar "\{"
		set opener 0
	} "\]" {
		set closingChar "\["
		set opener 0	
	} default {
		if {[string equal $openingChar "\""]} {
			set closingChar "\""
		} elseif {[string equal $behind "\""]} {
			set closingChar "\""
			set opener 0
		} else {
			return 0
		}
	}
	
	if {$opener} {
		set target [$widget index $mark+1chars]
		while {![info complete [$widget get $mark $target+1chars]]} {
			set target [$widget search $closingChar $target+1chars end]
			if {$target == ""} {return 0}
		}
		$widget tag add sel $mark $target+1chars
		return 1
	
	# Clicked closer
	} else {
		if {![string equal $openingChar "\"" ]} {
			# This is little slow (at start) Maybe just: foreach char in lines,
			# since normally used in short ranges?
			# Note: openingChar here is really a closer
			return [find_matching_opener $widget insert $openingChar]

		# Find opening quote (if clicked on right side of closing quote, not left)
		} else {
			set target $mark
			while {1} {
				set target [$widget search -backwards \" "$target-1c" 1.0]
				if {$target == ""} {return 0}
				set behind [$widget get $target-1c]
				if {![string equal $behind "\\" ] } {
					$widget tag add sel $target $mark
					return 1
				}
			}
		}
	}
}


# Called from: select_block
proc find_matching_opener { w start closer} {
	# text-widget
	set t $w
	
	if {[string equal $closer "\}"]} {
		set braces "\[\{\}\]|\n"
		set opener "\{"
	} else {
		set braces {[\[\]]|\n}
		set opener "\["
	}
	
	set cont [$t get 1.0 $start]
	set start_line [get_line_as_int $t $start]

	set tuples [regexp -all -inline -indices $braces $cont]
	#set tuples [regexp -all -inline $braces $cont]
	#puts $tuples
	
	set close_braces 1
	set line_no $start_line
	set i [llength $tuples]
	incr i -1
	set index 0
	
	# Start searching matching opener from end
	for {set i $i} {$i > -1} {incr i -1} {
		set tuple [lindex $tuples $i]
		set s [lindex $tuple 0]
		set brace [string index $cont $s]
		
		incr s -1
		set behind [string index $cont $s]

		if {[string equal $brace $closer]} {
			if {![string equal $behind "\\"]} {incr close_braces}
		} elseif {[string equal $brace $opener]} {
			if {![string equal $behind "\\"]} {incr close_braces -1}
		} else {incr line_no -1}
		
		# Found match, have line_no but need to calculate col
		if {!$close_braces} {
			incr s
			set index $s
			set col_offset 0
			
			# Find previous newline to get col_offset.
			# New loop, instead of flag in previous loop, to save some time
			incr i -1
			for {set i $i} {$i > -1} {incr i -1} {
				set tuple [lindex $tuples $i]
				set s [lindex $tuple 0]
				set brace [string index $cont $s]
				
				if {[string equal $brace "\n"]} {
					set col_offset $s
					# Calculate col
					set col $index
					incr col -$col_offset
					$t tag add sel "$line_no.$col -1c" "$start+1c"
					return 1
				}
			}
			# First line of file
			set col $index
			$t tag add sel $line_no.$col "$start+1c"
			return 1			
		}
	}
	return 0
}


#== Double-click braces End ===================#
#== Syntax highlight Begin ====================#

proc brace_check { editor_no } {
	global editor

	set t $editor($editor_no,text)
	set braces {[\{\}]|\n}
	set cont [$t get 1.0 end]
	
	set tuples [regexp -all -inline -indices $braces $cont]
	
	# Find first extra closer
	set open_braces 0
	set line_no 1

	foreach tuple $tuples {

		set s [lindex $tuple 0]
		set brace [string index $cont $s]
		# Arrange for: look-behind, since tcl-regexp does not
		incr s -1
		set behind [string index $cont $s]

		if {[string equal $brace "\{"]} {
			if {![string equal $behind "\\"]} {incr open_braces}
		} elseif {[string equal $brace "\}"]} {
			if {![string equal $behind "\\"]} {incr open_braces -1}
		} else {
			incr line_no
		}
		
		if {$open_braces < 0} {
			after 50 bell
			puts "Extra closer at or before line: $line_no"
			puts "Start searching from defline body opener brace. (double-click it)"
			return
		}
	}
	
	# Find last extra opener
	set close_braces 0
	set line_no [llength [split $cont "\n"]]
	set i [llength $tuples]
	incr i -1

	# Arrange for: lreverse, since tcl 8.4 does not
	for {set i $i} {$i > -1} {incr i -1} {
		set tuple [lindex $tuples $i]
		
		set s [lindex $tuple 0]		
		set brace [string index $cont $s]
		incr s -1
		set behind [string index $cont $s]

		if {[string equal $brace "\}"]} {
			if {![string equal $behind "\\"]} {incr close_braces}
		} elseif {[string equal $brace "\{"]} {
			if {![string equal $behind "\\"]} {incr close_braces -1}
		} else {
			incr line_no -1
		}
		
		if {$close_braces < 0} {
			after 50 bell
			puts "Extra opener at or after line: $line_no"
			puts "Start searching from end of proc-body, clicking closer braces."
			return
		}
	}	
}


# Used to highlight non-tcl files, currently only comments are highlighted
proc syntax_highlight_comments { editor_no start_line end_line } {
	global editor tokens

	set t $editor($editor_no,text)

	if {[string equal $end_line "end"]} {
		set end_orig $end_line
	} else {
		set end_orig $end_line.end
	}

	set line_no $start_line
	set tokens(comment) {}

	set cont [split [$t get $start_line.0 $end_orig] "\n"]
	
	foreach line $cont {
		set trimmed [string trim $line]
		# Line is not empty
		if {![string equal $trimmed ""] } {
			if {[string equal [string index $trimmed 0] "#"]} {
				lappend tokens(comment) $line_no.0 $line_no.end
			}
		}
		incr line_no
	}
	
	foreach tag {comment} {
		$t tag remove $tag $start_line.0 $end_orig
		if {[llength $tokens($tag)] > 0} [linsert $tokens($tag) 0 $t tag add $tag]
	}

	# Set "syntax" flag
	set editor($editor_no,syntax) 1
	
}


proc syntax_highlight { editor_no start_line end_line } {
	global editor tokens kwords
	
	set ext $editor($editor_no,extension)
	if {![string equal $ext ".tcl"] } {
		syntax_highlight_comments $editor_no $start_line $end_line
		return
	}
	
	set t $editor($editor_no,text)

	if {[string equal $end_line "end"]} {
		set end_orig $end_line
		set proc_no 0
		set editor($editor_no,procs) ""
	} else {
		set end_orig $end_line.end
		set proc_no $editor($editor_no,proc_no)
	}

	set line_no $start_line
	
	set line ""	
	#set t00 [clock clicks -milliseconds]
	set tokens(quot) {}
	set tokens(number) {}
	set tokens(comment) {}
	set tokens(proc) {}
	set tokens(variable) {}
	set tokens(command) {}
	if {0} {
	#set keys "etinrsodal\$fcpm_gxuwhby.0k1v24CAq385:jBEFDRS6ITL9MOWzPVX7UZGHJNKQY"
	# Note that there is tab-char and space-char around comma in delims
	# Should "%^" be added?
	}
	set delims {'"+-*/=~?!<>\\&|;	, ([\{\}])}

if {0} {
##	proc:    1 %
##	number:  9 %
##	quot:    9 %
##	comment:10 %
##	dollars:29 %
##	command:39 %
## 7500-7700ms
}

	set cont [split [$t get $start_line.0 $end_orig] "\n"]
	
	foreach line $cont {
		set trimmed [string trim $line]
		# Line is not empty
		if {![string equal $trimmed ""] } {
			set we [string wordend $trimmed 0]
			set first_word [string range $trimmed 0 [incr we -1]]

		if {[string equal [string index $trimmed 0] "#"]} {
			# Comment line, simply colour whole line
			lappend tokens(comment) $line_no.0 $line_no.end

		} elseif {[string equal $first_word "proc"]} {
			# Proc statement, colour whole line and add procname to proclist
			set end [string first " " $trimmed [incr we 2]]
			set proc_name [string trim [string range $trimmed $we $end]]
			
			if {![string equal $proc_name ""]} {
				incr proc_no
				$t mark set mark_$proc_no $line_no.0
				lappend editor($editor_no,procs) [list $proc_name $proc_no]					
				lappend tokens(proc) $line_no.0 $line_no.end
			}
			
		} else {
			# This is where almost all time is spent.
			# General line, check all words in curline and tag them.
			set flag_finish 0
			#set indentation [string first $first_word $line]
			set startx 0

			while {1} {

				# Handle quotes Begin
				set doubles [string first "\"" $line $startx]
				set singles [string first "'" $line $startx]
				set do_quotes 1				
					
				# No quotes on line (both are -1)
				if {$doubles == $singles} {
					set sooner "end"
					set do_quotes 0
					set flag_finish 1
					
				# Only double-quotes on line
				} elseif {$singles == -1} {
					set quot "\""
					set sooner $doubles

				# Only single-quotes on line
				} elseif {$doubles == -1} {
					set quot "'"
					set sooner $singles

				# There is both quotes on line
				} elseif {$doubles < $singles} {
					set quot "\""
					set sooner $doubles

				} else {
					set quot "'"
					set sooner $singles
				}
					
				### Handle quotes End #########

				if {![string equal $sooner "end"]} {incr sooner -1}
         
				set head [string range $line $startx $sooner]
				set words [split $head $delims]
				set s 0

				# Tag words
				foreach word $words {
                    
					if {![string equal $word ""]} {
						set len_word [string length $word]
						set s [string first $word $line $s]
						set e $s
						incr e $len_word

						if {[string equal [string index $word 0] "$"]} {
							lappend tokens(variable) $line_no.$s $line_no.$e
						} elseif {[lsearch -sorted $kwords $word] != -1} {
							lappend tokens(command) $line_no.$s $line_no.$e
						} elseif {[string is double -strict $word]} {
							lappend tokens(number) $line_no.$s $line_no.$e 
						}
						
						set s $e
					}
				}
				
				if {$flag_finish} {break}

				incr sooner

				if {$do_quotes} {
					set s $sooner
					set e [string first $quot $line [incr s]]

					if {$e != -1} {
						incr e
						lappend tokens(quot) $line_no.$sooner $line_no.$e
						set startx $e						
					} else {
						set startx $sooner
						incr startx
					}
				}
			}
			# This is after: while-loop
		}
		# After: else-general line
	}	
	# After: if line is not empty
	incr line_no
	}
	
	if {0} {
	# This is after main foreach-loop
	############
	# If taglist is not empty, expand it for not-so-wise: tag add.
	# (Not-so-wise meaning: it cant read from list!)
	# Do expansion by: inserting command: $t tag add proc (if tagging proc-tag)
	# into start , (idx 0), of this taglist: $tokens(proc)
	
	# Q: Why not just: $t tag add proc $tokens(proc)?
	# A: Again, tag add is not so wise, and when using tcl 8.4,
	# There is no list expansion operator, yet.
	# This could be done with eval also.
	
	# First remove all existing tags from text (excluding proc tag)
	}
	foreach tag {command comment quot number variable} {
		$t tag remove $tag $start_line.0 $end_orig
		if {[llength $tokens($tag)] > 0} [linsert $tokens($tag) 0 $t tag add $tag]
	}
	if {[llength $tokens(proc)] > 0} [linsert $tokens(proc) 0 $t tag add proc]
	############
	
	
	#set t22 [clock clicks -milliseconds]
	#set t1t2 [expr {$t22-$t00}]
	#puts "syntax highlight took $t1t2 ms"
	
	# Store most recent procedure number (proc_no)
	set editor($editor_no,proc_no) $proc_no

	# Set "syntax" flag
	set editor($editor_no,syntax) 1
}


proc toggle_syntax {} {
	global editor

	foreach name [lsort -dictionary [array names editor *,status]] {
		set editor_no [lindex [split $name ","] 0]
		if {$editor($editor_no,status) != "CLOSED"} {
			set t $editor($editor_no,text)
			if {!$editor(syntax)} {
				puts "syntax on"
			} else {
				puts "syntax off"
			}
		}
	}
	
	if {!$editor(syntax)} {set editor(syntax) 1
	} else {set editor(syntax) 0}
	
}


# Using active looping instead of 'passive'(everything gets filtered!) event-based-method
# because now can avoid use of proxy-text and event-callback-result overhead when typing
# --> Editor is now much more responsive
proc syntax_check_loop {} {
	global editor
	set editor_no $editor(current)
	
	set tmp0 $editor($editor_no,data)
	set t $editor($editor_no,text)
	set cont0 [$t get 1.0 end]
	set tmp [split $tmp0 "\n"]
	set cont [split $cont0 "\n"]

	if {![string equal $cont0 $tmp0]} {
		# Search diff_line from start
		set flag 0
		set len_cont [llength $cont]
		
		for {set i 1} {$i < $len_cont} {incr i} {
			set line_tmp [lindex $tmp $i]
			set line_cont [lindex $cont $i]
			if {![string equal $line_tmp $line_cont]} {
				set flag 1
				break
			}
		}

		if {$flag} {
			# Search diff_line from end
			set line_start [incr i]
			set line_end $line_start
			set num_lines_to_end $len_cont
			incr num_lines_to_end -$line_start
			
			for {set i 0} {$i < $num_lines_to_end} {incr i} {
				set line_tmp [lindex $tmp end-$i]
				set line_cont [lindex $cont end-$i]
				if {![string equal $line_tmp $line_cont]} {
					set line_end $len_cont
					incr line_end -$i
					break
				}
			}
			#puts "$editor_no $line_start $line_end" 
			syntax_highlight $editor_no $line_start $line_end
			set editor($editor_no,status) MODIFIED
		}
 		set editor($editor_no,data) $cont0
	}
	
	after 10000 syntax_check_loop
}


#== Syntax highlight End ================================#
#=== Proclist window related Begin =============#

# This procedure hasn't been tested to work yet
# "delete" event needs to be modified to remove all marks within deleted text
proc validate_procedures { editor_no } {
	global editor
	set t $editor($editor_no,text)

	# Check each procedure mark still exists, if not then delete procedure name
	set index 0
	foreach procs $editor($editor_no,procs) {
		set no [lindex $procs 1]
		if {[$t index mark_$no] == ""} {
			set editor($editor_no,procs) [lreplace $editor($editor_no,procs) $index $index]
		}
		incr index
	}
}


# Update right hand panel which includes file/directory, status and procedures
# Called to update cursor position
proc update_status { editor_no } {
	global editor

	set sw $editor($editor_no,status_window)
	set t $editor($editor_no,text)

	$sw configure -state normal
	$sw delete 1.0 end

	$sw insert end "File:\t$editor($editor_no,title)\n"
	$sw insert end "Dir:\t[file dirname $editor($editor_no,file)]\n"
	$sw insert end "Editor:\tVersion $editor(version)\n"
	$sw insert end "Status:\t$editor($editor_no,status)\n"
	$sw insert end "Position:\t[$t index insert]\n"
	$sw insert end "Font:\t[$t cget -font]\n\n"

	foreach procs [lsort -index 0 $editor($editor_no,procs)] {
		set proc [lindex $procs 0]
		set no [lindex $procs 1]
		set original_bg [$sw cget -background]
		$sw tag bind proc_$no <Enter> "$sw tag configure proc_$no -background skyblue1"
		$sw tag bind proc_$no <Leave> "$sw tag configure proc_$no -background $original_bg"
		$sw tag bind proc_$no <1> "$t mark set insert mark_$no;$t see insert;update_status $editor_no"
		$sw insert end "$proc\n" proc_$no
	}

	$sw configure -state disabled
}


#=== Proclist window related End ======================#
#== Search related Begin ==============================#

proc search_find { editor_no } {
	global editor

	set w .find

	# Destroy find-window if it already exists
	if {[winfo exists $w]} { destroy $w }

	# Create new find-window
	toplevel $w
	wm transient $w .
	wm title $w "Find"

	set f1 [frame $w.f1]
	set f2 [frame $w.f2]

	set ft [frame $f1.top]
	label $ft.text -text "Find What?"
	set entry [combobox::combobox $ft.find -width 30 -value [lindex $editor(find_history) 0]]
	pack $ft.text -side left -anchor nw -padx 4 -pady 4
	pack $entry -side left -anchor nw -padx 4 -pady 4
	pack $ft -side top -anchor nw

	checkbutton $f1.case -text "Match Case?" -variable editor(match_case)
	pack $f1.case -side left -padx 4 -pady 4

	# Populate combobox with editor find history
	foreach string $editor(find_history) {
		$entry list insert end $string
	}

	button $f2.find -text "Find Next" -command "search_find_command $editor_no $w $entry" -width 10
	button $f2.cancel -text "Cancel" -command "destroy $w" -width 10
	pack $f2.find -side top -padx 8 -pady 4
	pack $f2.cancel -side top -padx 8 -pady 4

	pack $f1 -side left -anchor nw
	pack $f2 -side left -anchor nw

	bind $entry.entry <Return> "+search_find_command $editor_no $w $entry"
	bind $entry.entry <Escape> "destroy $w"
	bind $entry.entry <Alt-v> "event generate $entry.entry <<Paste>>;break"
	bind $entry.top.list <ButtonRelease-3> "remove_history $editor_no $w $entry; break"

	focus -force $entry
	center_window $w
}


proc remove_history { editor_no w entry } {
	global editor
	set idx [$entry list index active]
	$entry list delete active
	# Remove string from find history
	set editor(find_history) [lreplace $editor(find_history) $idx $idx]
	# To remove index: idx from list: mylist
	# lreplace $mylist $idx $idx
}


proc search_find_command { editor_no w entry } {
	global editor
	set editor(find_string) [$entry get]
	destroy $w

	# If null string, do nothing
	if {$editor(find_string) == ""} {
		return
	}

	# Search again (starting from current position)
	search_find_next $editor_no F3
}


proc search_find_next { editor_no {key F3}} {
	global editor
	set t $editor($editor_no,text)

	# Check/add string to find history
	set list [lsearch -exact $editor(find_history) $editor(find_string)]
	if {$list != -1} {
		# This deletes found item from history (so it can be added to top)
		set editor(find_history) [lreplace $editor(find_history) $list $list]
	}

	set editor(find_history) [linsert $editor(find_history) 0 $editor(find_string)]


	set pos [$t index insert]
	set s "1.0"
	set e "end"

	# Backwards
	if {$key == "F4"} {
		set s "end"
		set e "1.0"
	}

	# Searching 'again'
	if {![string equal "" $editor(last_find_string)] && [string equal $editor(find_string) $editor(last_find_string)]} {
		set s $pos
		if {$key == "F4"} {set e "1.0"}
	}


	# Do search
	set find_string $editor(find_string)

	# Backwards
	if {$key == "F4"} {
		if {$editor(match_case)} {set pos [$t search -backwards -- $find_string $s $e]
		} else {set pos [$t search -backwards -nocase -- $find_string $s $e]}
	# Forwards
	} elseif {$editor(match_case)} {set pos [$t search -- $find_string $s $e]
	} else {set pos [$t search -nocase -- $find_string $s $e]}


	# If found then move insert cursor to that position
	if {$pos != ""} {
		$t mark set insert $pos
		$t see $pos

		set editor(last_find_string) $editor(find_string)

		# Highlight found word
		set line [lindex [split $pos "."] 0]
		set x [lindex [split $pos "."] 1]
		set x [expr {$x + [string length $editor(find_string)]}]
		$t tag remove sel 1.0 end
		$t tag add sel $pos $line.$x

		if {$key == "F3"} {
			# Put cursor at selend, to enable continuing searching
			$t mark set insert $line.$x
			$t see $line.0
		}

		focus -force $t
		update_status $editor_no
		return 1

	} else {
		bell
		set editor(last_find_string) ""
		return 0
	}
}


proc search_replace { editor_no } {
	global editor

	set w .find

	# Destroy find window if it already exists
	if {[winfo exists $w]} { destroy $w }

	# Create new "find" window
	toplevel $w
	wm transient $w .
	wm title $w "Find & Replace"

	set f1 [frame $w.f1]
	set f2 [frame $w.f2]

	set ft [frame $f1.top]
	label $ft.text -text "Find What?" -width 15
	set entry [combobox::combobox $ft.find -width 30 -value [lindex $editor(find_history) 0]]
	pack $ft.text -side left -anchor nw -padx 4 -pady 4
	pack $entry -side left -anchor nw -padx 4 -pady 4
	pack $ft -side top -anchor nw

	set rt [frame $f1.bot]
	label $rt.text -text "Replace with" -width 15
	set replace [combobox::combobox $rt.replace -width 30 -value [lindex $editor(replace_history) 0]]
	pack $rt.text -side left -anchor nw -padx 4 -pady 4
	pack $replace -side left -anchor nw -padx 4 -pady 4
	pack $rt -side top -anchor nw

	checkbutton $f1.case -text "Match Case?" -variable editor(match_case)
	pack $f1.case -side left -padx 4 -pady 4

	# Populate combobox with editor find history
	foreach string $editor(find_history) {
		$entry list insert end $string
	}

	# Populate combobox with editor replace history
	foreach string $editor(replace_history) {
		$replace list insert end $string
	}

	button $f2.find -text "Find Next" -command "search_replace_command $editor_no $w $entry $replace find" -width 10 -pady 0
	button $f2.find1 -text "Replace" -command "search_replace_command $editor_no $w $entry $replace replace" -width 10 -pady 0
	button $f2.find2 -text "Replace All" -command "search_replace_command $editor_no $w $entry $replace all" -width 10 -pady 0
	button $f2.cancel -text "Cancel" -command "destroy $w" -width 10 -pady 0
	pack $f2.find -side top -padx 8 -pady 2
	pack $f2.find1 -side top -padx 8 -pady 2
	pack $f2.find2 -side top -padx 8 -pady 2
	pack $f2.cancel -side top -padx 8 -pady 2

	pack $f1 -side left -anchor nw
	pack $f2 -side left -anchor nw

	bind $entry.entry <Escape> "destroy $w"
	bind $replace.entry <Escape> "destroy $w"

	focus -force $entry
	center_window $w
}


proc search_replace_command { editor_no w entry replace command } {
	global editor
	set editor(find_string) [$entry get]
	set editor(replace_string) [$replace get]
	set t $editor($editor_no,text)

	# Check/add string to find history
	set list [lsearch -exact $editor(find_history) $editor(find_string)]
	if {$list != -1} {
		set editor(find_history) [lreplace $editor(find_history) $list $list]
	}
	set editor(find_history) [linsert $editor(find_history) 0 $editor(find_string)]

	# Check/add string to replace history
	set list [lsearch -exact $editor(replace_history) $editor(replace_string)]
	if {$list != -1} {
		set editor(replace_history) [lreplace $editor(replace_history) $list $list]
	}
	set editor(replace_history) [linsert $editor(replace_history) 0 $editor(replace_string)]

	switch -- $command {
		"find" {
			# Search "again" (starting from current position)
			search_find_next $editor_no
		}
		"replace" {
			# There is no selection
			if {![llength [$t tag ranges sel]]} {
				search_find_next $editor_no

			} else {replace_one $editor_no 1}
		}
		"all" {
			set replace_count 0
			if {[replace_one $editor_no 0]} {
				incr replace_count
				while {[replace_one $editor_no 0]} {
					incr replace_count
				}
			}
			tk_messageBox -icon info -title "Replace" -message "$replace_count item(s) replaced."
			destroy $w
		}
	}
}


proc replace_one { editor_no {one 0}} {
	global editor

	# Replacing just one or all
	if {$one || [search_find_next $editor_no]} {
		set t $editor($editor_no,text)
		set selected [$t tag ranges sel]
		set start [lindex $selected 0]
		set end [lindex $selected 1]
		$t delete $start $end
		$t insert [$t index insert] $editor(replace_string)
		return 1

	} else {return 0}
}


#== Search related End =======================================#
#== Grep search (find in files) ==============================#

proc grep_search { editor_no } {
	global editor

	set w .grep

	# Destroy find window if it already exists
	if {[winfo exists $w]} { destroy $w }

	# Create new "find" window
	toplevel $w
	wm transient $w .
	wm title $w "Grep"

	set f1 [frame $w.f1]
	set f2 [frame $w.f2]

	set ft [frame $f1.top]
	label $ft.text -text "Find What?" -width 12
	set entry [combobox::combobox $ft.find -width 30 -value [lindex $editor(find_history) 0]]
	pack $ft.text -side left -anchor nw -padx 4 -pady 4
	pack $entry -side left -anchor nw -padx 4 -pady 4
	pack $ft -side top -anchor nw

	set fp [frame $f1.path]
	label $fp.text -text "Search Path" -width 12
	entry $fp.entry -width 30 -textvariable editor(grep_path)
	pack $fp.text -side left -anchor nw -padx 4 -pady 4
	pack $fp.entry -side left -anchor nw -padx 4 -pady 4
	pack $fp -side top -anchor nw

	set editor(grep_ext) $editor(default_ext)
	set fe [frame $f1.ext]
	label $fe.text -text "Search Ext" -width 12
	entry $fe.entry -width 30 -textvariable editor(grep_ext)
	pack $fe.text -side left -anchor nw -padx 4 -pady 4
	pack $fe.entry -side left -anchor nw -padx 4 -pady 4
	pack $fe -side top -anchor nw

	checkbutton $f1.case -text "Match Case?" -variable editor(match_case)
	pack $f1.case -side left -padx 4 -pady 4

	# Populate combobox with editor find history
	foreach string $editor(find_history) {
		$entry list insert end $string
	}

	button $f2.find -text "Start" -command "grep_search_now $w $entry" -width 10
	button $f2.cancel -text "Cancel" -command "destroy $w" -width 10
	pack $f2.find -side top -padx 8 -pady 4
	pack $f2.cancel -side top -padx 8 -pady 4

	pack $f1 -side left -anchor nw
	pack $f2 -side left -anchor nw

	bind $entry.entry <Return> "+grep_search_now $w $entry"
	bind $entry.entry <Escape> "destroy $w"

	focus -force $entry
	center_window $w
}


proc grep_search_now { w entry } {
	global editor
	set editor(find_string) [$entry get]
	destroy $w

	# Null string? do nothing
	if {$editor(find_string) == ""} {
		return
	}

	# Check/add string to find history
	set list [lsearch -exact $editor(find_history) $editor(find_string)]
	if {$list != -1} {
		set editor(find_history) [lreplace $editor(find_history) $list $list]
	}
	set editor(find_history) [linsert $editor(find_history) 0 $editor(find_string)]

	# Now get list of all files to open
	# Has file already been loaded? if not open it
	# Search file, display results in a window

	# Make new editor window
	set editor_no [make_editor]

	set editor($editor_no,title) "Grep Search Results: $editor(find_string)"
	wm title . $editor($editor_no,title)

	set t $editor($editor_no,text)

	$t insert end "Search String: $editor(find_string)\nSearch Path: $editor(grep_path)\nSearch Ext: $editor(grep_ext)\n\n"

	# Get list of files
	variable file_list {}
	grep_add_files ".[string trim $editor(grep_ext) .]" $editor(grep_path)

	set editor(grep_matches) 0

	set st [text .hidden]
	set tag_no 0

	# Search each file
	foreach file [lsort -dictionary $file_list] {
		set file_tag tag[incr tag_no]

		$t insert end "$file ...\n" $file_tag
		$t see end
		update

		set matches 0

		# Open file (if not open already?)
		set fid [open $file]
		$st insert end [read -nonewline $fid]
		close $fid

		# Search file
		# Attempt to find string
		set current "1.0"

		while {1} {
			if {$editor(match_case)} {
				set pos [$st search -- $editor(find_string) $current end]
			} else {
				set pos [$st search -nocase -- $editor(find_string) $current end]
			}

			if {$pos != ""} {
				incr matches

				set line [lindex [split $pos .] 0]
				set current "$line.end"

				set tag tag[incr tag_no]
				set data [string trim [$st get "$line.0" "$line.end"]]
				$t insert end "\t$line: $data\n" $tag

				set bg [$t cget -background]
				$t tag bind $tag <Enter> "$t tag configure $tag -background skyblue"
				$t tag bind $tag <Leave> "$t tag configure $tag -background $bg"

				$t tag bind $tag <1> [list grep_click $file $pos]
			} else {
				break
			}
		}

		# Remove contents from file
		$st delete 1.0 end

		# Configure "tag" for highlighting purposes
		if {$matches} {
			$t insert end "\n"
			incr editor(grep_matches) $matches
		} else {
			$t delete $file_tag.first $file_tag.last
		}
	}

	destroy $st

	$t insert end "\n[llength $file_list] file(s) were searched, $editor(grep_matches) match(es) were found.\n"
	$t insert end "Move mouse over any search result and click to open file and display match.\n"
	$t see end

	# Clear status - default is "not modified"
	set editor($editor_no,status) ""
}


proc grep_add_files { ext dir } {
	variable file_list

	set pattern [file join $dir *]

	foreach filename [glob -nocomplain $pattern] {
		if {[file isdirectory $filename]} {
			grep_add_files $ext $filename
		}

		if {[file isfile $filename]} {
			if {[string tolower [file extension $filename]] == [string tolower $ext]} {
				lappend file_list $filename
			}
		}
	}
}


proc grep_click { file pos } {
	global editor

	# Is file already in memory?
	set active 0
	foreach name [lsort -dictionary [array names editor *,file]] {
		set no [lindex [split $name ","] 0]
		if {$editor($no,status) != "CLOSED" && [string equal -nocase $editor($no,file) $file]} {
			set editor_no $no
			set active 1
			break
		}
	}
	if {!$active} {
		set editor_no [make_editor $file 0 0]
	}

	set t $editor($editor_no,text)
	make_window_active $editor_no
	$t mark set insert $pos
	$t see insert
}


#== Grep search (find in files) End ==============================#
#== Goto_line Begin ==============================================#

proc goto_line { editor_no } {
	global editor

	set w .goto

	# Destroy find window if it already exists
	if {[winfo exists $w]} { destroy $w }

	# Create new "goto" window
	toplevel $w
	wm transient $w .
	wm title $w "Goto Line"

	label $w.text -text "Goto Line"
	entry $w.goto -width 6 -validate key -validatecommand "validate_number %W %P"
	pack $w.text $w.goto -side left -anchor nw

	bind $w.goto <Return> "+goto_line_no $editor_no $w"
	bind $w.goto <Escape> "destroy $w"
	focus -force $w.goto

	center_window $w
}


proc validate_number { w new_value } {
	if {[string is integer $new_value]} {
		return 1
	} else {
		bell
		return 0
	}
}


proc goto_line_no { editor_no w } {
	global editor
	set line_no [$w.goto get]
	destroy $w

	catch {
		set t $editor($editor_no,text)
		$t mark set insert $line_no.0
		$t see insert
	}
}


#== Goto_line End ====================================#
#== To be organised Begin ============================#

proc center_window { w } {
	after idle "
		update idletasks

		set xmax \[winfo screenwidth $w\]
		set ymax \[winfo screenheight $w\]
		set x \[expr \{(\$xmax - \[winfo reqwidth $w\]) / 2\}\]
		set y \[expr \{(\$ymax - \[winfo reqheight $w\]) / 2\}\]

		wm geometry $w \"+\$x+\$y\""
}


# Logging debug messages
proc log {message} {
	set fid [open "ml.log" a+]
	set time [clock format [clock seconds] -format "%d-%m-%Y %I:%M:%S %p"]
	puts $fid "$time  $message"
	close $fid
}


# Right click on any word and a popup menu offers "find WORD" option.
# This is same as user pressing "Search-Find" (ctrl-f) then entering word to search
proc popup_text_menu {editor_no x y} {
	global editor
	set t $editor($editor_no,text)

	# Place insert cursor at mouse pointer
	$t mark set insert @$x,$y
	set pos [$t index insert]

	# Get first being clicked-on
	set string [string trim [$t get "insert wordstart" "insert wordend"]]

	# Create pop-up menu for "find word"
	set pw .popup
	catch {destroy $pw}
	menu $pw -tearoff false

	# If mouse was clicked over a word then offer this word for "find"
	if {$string != ""} {
		$pw add command -label "Find \"$string\"" -command [list popup_find_text $editor_no $string]

		# If string is a procedure name then allow user to go directly to procedure definition
		foreach procs $editor($editor_no,procs) {
			set proc [lindex $procs 0]
			set no [lindex $procs 1]
			if {$proc == $string} {
				$pw add command -label "Goto \"$string\" definition" -command "$t mark set insert mark_$no;$t see insert;update_status $editor_no"
				break
			}
		}

		$pw add separator
	}
	# Display "undo" option
	$pw add command -label "Undo" -command "$t undo" -underline 0 -accelerator Ctrl+Z
	$pw add separator
	# Display usual cut/copy/paste options
	$pw add command -label "Cut" -command "tk_textCut $t" -underline 0 -accelerator Ctrl+X
	$pw add command -label "Copy" -command "tk_textCopy $t" -underline 0 -accelerator Ctrl+C
	$pw add command -label "Paste" -command "tk_textPaste $t" -underline 0 -accelerator Ctrl+V
	tk_popup $pw $x $y
}


proc popup_find_text { editor_no string } {
	global editor
	set editor(find_string) $string
	search_find_next $editor_no
}


proc toggle_word_wrap { editor_no } {
	global editor

	set t $editor($editor_no,text)
	switch -- $editor($editor_no,wordwrap) {
		1 { $t configure -wrap word }
		default { $t configure -wrap none }
	}
}


proc view_font_size { editor_no increment } {
	global editor
	set t $editor($editor_no,text)

	set font [$t cget -font]
	set size [lindex $font 1]
	incr size $increment
	set font [lreplace $font 1 1 $size]
	
	$t configure -font $font
	puts [$t cget -font]
	
	# For some reason this is not ok:
	#return "break"
}


proc configure_window {} {
    global testrun

	# Trap Exit [X] button "exit editor"
	wm protocol . WM_DELETE_WINDOW "exit_editor"

	# On windows maximise window by default
	global tcl_platform
	if {!$testrun && $tcl_platform(platform) == "windows" && [info tclversion] >= 8.3} {
		wm state . zoomed
	}
}
	

#== To be organised End ========================#
#=== Overrides Begin ===========================#

# 'Peeking', scrolling without moving insertion-cursor
proc center_view {editor_no key} {
	global editor

	# There must not to be space after comma
	set t $editor($editor_no,text)

	# To copy from edit.com: use selection tool
	set text_widget_height [winfo height $t]

	# Get last list item from list generated by bbox
	set bbox_height [lindex [$t bbox @0,0] end]
	#puts "$text_widget_height $bbox_height"

	# a/b is floored by default --> same as a//b in python
	set num_lines [expr {$text_widget_height/$bbox_height}]
	set num_scroll [expr {$num_lines/3}]

	set pos [$t index insert]
	# Lastline of visible window
	set lastline_screen [expr {int(floor([$t index @0,65535]))}]

	# Lastline
	set lastline [expr {int(floor([$t index end])) -1}]
	set curline [expr {int(floor([$t index insert])) -1}]

	if {[string equal $key u] } {
		set num_scroll [expr {$num_scroll*-1}]

		# Near fileend
		} elseif { [expr {$curline + 2*$num_scroll + 2 > $lastline}] } {
			$t insert end [string repeat "\n" $num_scroll]
			$t mark set insert $pos
	}

	# Near screen end
	#elif curline + 2*num_scroll + 2 > lastline_screen:
	$t yview scroll $num_scroll units

}


proc return_override {w} {
	set idx [split [$w index insert] "."]
	set line [lindex $idx 0]
	set col [lindex $idx 1]

	proc finish_return {w line} {
		$w see "[expr {$line + 1}].0"
		$w edit separator
		return "break"
		}

	# Cursor is at indent0
	if {$col == 0} {
		$w insert insert "\n"
		return [finish_return $w $line]
	}

	set tmp [$w get "insert linestart" "insert lineend"]
	set left_part [string range $tmp 0 [expr {$col - 1}]]
	set right_part [string range $tmp $col end]

	# Cursor is inside indentation and line is not empty
	if {[string is space $left_part] && ![string is space $right_part] && $right_part ne ""} {
		$w insert insert "\n"
		$w insert "[expr {$line + 1}].0" $left_part
		return [finish_return $w $line]

	} else {
		if {[string is space $right_part]} {
			$w delete insert "insert lineend"
		}

		# Count indentation depth
		set i 0
		while {$i < [string length $left_part] && [string index $left_part $i] eq "\t"} {
			incr i
		}

		# Insert newline and add indentation
		$w insert insert "\n"
		$w insert insert [string repeat "\t" $i]
		return [finish_return $w $line]
	}
}


proc check_indent_depth {w} {
	set contents [$w get 1.0 end]
	
	# Keywords of interest
	set words {"proc " "if " "for " "while "}
	set lines [split $contents "\n"]
	set num_lines [llength $lines]
	
	for {set i 0} {$i < $num_lines} {incr i} {
		set line [lindex $lines $i]
		set trimmed_line [string trim $line]

		set found_word 0
		foreach word $words {
			if {[string match $word* $trimmed_line]} {
				set found_word 1
				break
			}
		}

		# If at start of multiline block
		if {!$found_word || [string index $trimmed_line end] ne "\{"} {continue}

		# Then get next non-empty line
		set next_line ""
		for {set offset [expr {$i + 1}]} {$offset < $num_lines} {incr offset} {
			set tmp [lindex $lines $offset]
			if {![string equal [string trim $tmp] ""]} {
				set next_line $tmp
				break
			}
		}

		# Fail --> continue to next line
		if {[string equal $next_line ""]} continue

		# Success: found non-empty next_line for current kword, start to count indent_diff
		set indent_0 [expr {[string length $line] - [string length [string trimleft $line " \t"]]}]

		set indent_1 0
		set flag_space 0

		# Count indent of next_line
		set chars [split $next_line ""]
		foreach char $chars {
			if {$char eq " "} {
				set flag_space 1
				incr indent_1
			} elseif {$char eq "\t"} {
				incr indent_1
			} else {
				break
			}
		}


		set indent_diff [expr {$indent_1 - $indent_0}]

		# Bad indentation
		if {$indent_diff <= 0 || (!$flag_space && $indent_diff > 1)} {continue}
		
		# Below this: success
		
		# Already tabbed
		if {!$flag_space} {
			puts "Already tabbed"
			return [list 1 0]
		}
		
		puts "Not tabbed, indent_depth: $indent_diff"
		return [list 0 $indent_diff]
	}

	puts "Check failed, assuming already tabbed or empty"
	return [list 1 0]
}


proc move_manylines { w key} {
	global editor

	set line [get_line_as_int $w]

	set bbox_height $editor(bbox_height)
	set text_widget_height $editor(text_widget_height)
	set num_lines [expr {$text_widget_height/$bbox_height}]

	# Lastline of visible window
	set lastline_screen [expr {int(floor([$w index @0,65535]))}]
	set firstline_screen [expr {$lastline_screen - $num_lines}]
	set curline [expr {int(floor([$w index insert])) -1}]
	set to_up [expr {$curline - $firstline_screen}]
	set to_down [expr {$lastline_screen - $curline}]

	set near [expr {$to_down < 10 ? 1 : 0}]
	set mult 1
	if {$key == "Up"} {
		set mult -1
		set near [expr {$to_up < 10 ? 1 : 0}]
	}

	# First line without wait, since there is some overhead already
	set line [expr {$line +$mult}]
	$w mark set insert $line.0
	if {$near} {
		$w yview scroll $mult units
		update idletasks
		}
	$w see $line.0

	set waiting 28
	if {$near} {	set waiting 12}

	# Apply wait to rest of lines
	for {set x 1} {$x < 10} {incr x} {
		set line [expr {$line +$mult}]
		set wait [expr {$x*$waiting}]

		# After script has to be in quotation marks instead of curlies
		# If want to access variables
		after $wait "$w mark set insert $line.0
				if {$near} {
					$w yview scroll $mult units
					update idletasks
					}
				$w see $line.0"
	}
}


proc get_line_as_int { w {index insert} } {return [lindex [split [$w index $index] '.'] 0]}
proc get_col_as_int { w {index insert} } {return [lindex [split [$w index $index] '.'] 1]}


proc test_run {editor_no} {
	global editor
	set file $editor($editor_no,file)
	set fid [open $file w+]
	set t $editor($editor_no,text)
	puts -nonewline $fid [$t get 1.0 end]
	close $fid
	
	######
    set dirname "."
	set fname "ml.tcl"
	
	# Create and initialize slave interpreter
	set slave [interp create slave]
	
	#load {} Tk slave
	set cmd [list source [file join $dirname $fname]]
	$slave eval "set argv {--debug}"
	
	if [catch {$slave eval $cmd} result] {
		puts "TESTRUN FAIL"
		
		global errorInfo
		puts "\nTraceback, raising call first.\n"
		#puts "Linenumbers for procs are counted from definition line:\n"
		regexp {\(procedure \"(\w+)\" line (\d+)} $errorInfo m0 procname line
		#puts stderr "$procname $line"		
		puts stderr $errorInfo
		
		set pos [$t search -- "proc $procname" 1.0]
		set pos [$t index "$pos +$line lines +1l linestart"]
		$t mark set insert $pos 
		
##		set chan [open err.txt w]
##		puts $chan $errorInfo
##		close $chan
##		puts "\nerror is saved to: err.txt"
 

	} else {puts "TESTRUN OK"}
	

	interp delete slave
	######
}


proc get_ind_depth { w {index insert} } {
	# Get line
	set tmp [$w get {insert linestart} {insert lineend} ]

	# Get indent lenght
	set len_line [string length $tmp]
	set len_trim [string length [string trimleft $tmp]]

	return [expr {$len_line - $len_trim}]
}


proc indentation_add { editor_no } {
	global editor

	set t $editor($editor_no,text)
	if {[$t tag ranges sel] == ""} {
		$t insert insert "\t"
		return
	}
	
	# Get line-range of selection
	set s [get_line_as_int $t sel.first]
	set e [get_line_as_int $t sel.last]

	for {set x $s} {$x <= $e} {incr x} {$t insert $x.0 "\t"}
}


proc indentation_remove { editor_no } {
	global editor

	set t $editor($editor_no,text)
	if {[$t tag ranges sel] == ""} {
		$t delete {insert linestart} {insert linestart +1c}
		return
	}
	
	# Get line-range of selection
	set s [get_line_as_int $t sel.first]
	set e [get_line_as_int $t sel.last]

	for {set x $s} {$x <= $e} {incr x} {$t delete $x.0 $x.1}
}


proc comment_add { editor_no } {
	global editor
	
	set t $editor($editor_no,text)
	
	# Get line-range of selection
	set s [get_line_as_int $t sel.first]
	set e [get_line_as_int $t sel.last]
	
	for {set x $s} {$x <= $e} {incr x} {$t insert $x.0 "##"}

}


proc comment_remove { editor_no } {
	global editor

	set t $editor($editor_no,text)

	# Get line-range of selection
	set s [get_line_as_int $t sel.first]
	set e [get_line_as_int $t sel.last]

	for {set x $s} {$x <= $e} {incr x} {$t delete $x.0 $x.2}

}


proc goto_linestart { editor_no } {
	global editor

	set t $editor($editor_no,text)

	# Put cursor after indentation
	set ind [get_ind_depth $t]
	$t mark set insert "insert linestart +$ind\c"
}


proc replace_4_spaces { editor_no } {
	global editor
	set t $editor($editor_no,text)

	set cont [split [$t get 1.0 end] "\n"]
	set lines ""

	# Assumptions: tab-lenght is 4 spaces, lines have only spaces in indentation
	# --> does not work if there is mix of tabs and spaces in indentation
	foreach line $cont {
		
		# First, strip whitespace from lines
		set tmp [string trimright $line]
		set num_spaces 0

		for {set x 0} {$x < [string length $line]} {incr x} {
			if {[string index $line $x] eq " "} {
				incr num_spaces
				set tmp [string trimleft $tmp " "]
			} else {
				break
			}
		}

		set num_tabs [expr {$num_spaces/4}]
		set indent [string repeat "\t" $num_tabs]
		set ind_str "$indent$tmp"
		lappend lines $ind_str
	}

	$t delete 1.0 end
	$t insert 1.0 [join $lines "\n"]
	
}


#==== Overrides End ========================== #
#==== File-menu Begin ======================== #

proc open_file { editor_no } {
	global editor
	global file_types

	set file $editor($editor_no,file)
	if {$file != ""} {
		set pwd [file dirname $file]
		set ext $editor($editor_no,extension)
	} else {
		set pwd [pwd]
		set ext $editor(default_ext)
	}

	set file [tk_getOpenFile -title "Open File" -initialdir $pwd \
		-defaultextension ".*" -filetypes $file_types]

	if {$file != ""} {
		update idletasks
		make_editor $file
	}
}


proc save_file { editor_no } {
	global editor
	set file $editor($editor_no,file)

	if {$file == ""} {
		save_file_as $editor_no
	} else {
		set fid [open $file w+]
		set t $editor($editor_no,text)
		puts -nonewline $fid [$t get 1.0 end]
		close $fid
		set editor($editor_no,status) ""

		# Previously we undid "undo" status after saving
		# Now allow undo to go back since file was originally opened
	}
}


proc save_file_as { editor_no } {
	global editor
	global file_types
	set file $editor($editor_no,file)

	set file [tk_getSaveFile -title "Save File" -initialdir [pwd] \
		-initialfile $file -filetypes $file_types]

	if {$file != ""} {
		set fid [open $file w+]
		set t $editor($editor_no,text)
		puts -nonewline $fid [$t get 1.0 end]
		close $fid
		set editor($editor_no,status) ""
		set editor($editor_no,file) $file
		set editor($editor_no,title) [file tail $file]
		wm title . $editor($editor_no,title)

		# Reset undo status
		set t $editor($editor_no,text)
        #$t reset_undo

		# Update file extension, this is used for syntax highlighting commands
		set editor($editor_no,extension) [string tolower [file extension $file]]
	}
}


proc close_window { editor_no {action ""} } {
	global editor

	# Check status of window before closing
	while {$editor($editor_no,status) == "MODIFIED"} {
		set option [tk_messageBox -title "Save Changes?" -icon question -type yesnocancel -default yes \
			-message "File \"$editor($editor_no,file)\" has been modified.\nDo you want to save changes?"]

		if {$option == "yes"} {
			save_file $editor_no
		} elseif {$option != "no"} {
			return 0
		} else {
			break
		}
	}

	destroy $editor($editor_no,window)
	set editor($editor_no,status) "CLOSED"

	# Make another window active - if any?
	set active 0
	foreach name [lsort -dictionary [array names editor *,file]] {
		set no [lindex [split $name ","] 0]
		if {$editor($no,status) != "CLOSED"} {
			make_window_active $no
			set active 1
			break
		}
	}

	if {!$active && $action != "exit"} { make_editor }

	return 1
}


proc exit_editor {} {
	global editor
	global syntax

	set t $editor($editor(current),text)

	# First save configuration file "ml_cfg.ml"
	set fid [open [file join $editor(initial_dir) "ml_cfg.ml"] w]
	puts $fid "# ML editor configuration file - AUTO GENERATED"
	puts $fid "# DO NOT EDIT THIS FILE WITH \"ML\", USE ANOTHER EDITOR (BECAUSE ML WILL OVERWRITE YOUR CHANGES)"
	puts $fid ""

	puts $fid "# find & file history"
	set file_history ""
	foreach name [lsort -dictionary [array names editor *,status]] {
		set no [lindex [split $name ","] 0]
		if {$editor($no,status) != "CLOSED"} {
			if {$editor($no,file) != ""} {
				lappend file_history $editor($no,file)
			}
		}
	}
	puts $fid "set editor(find_history) [list [lrange $editor(find_history) 0 19]]"
	puts $fid "set editor(replace_history) [list [lrange $editor(replace_history) 0 19]]"
	puts $fid "set editor(file_history) [list $file_history]"
	puts $fid ""

	puts $fid "# cursor position"
	puts $fid "set editor(lastpos) [expr {int(floor([$t index insert]))}].0"
	puts $fid ""

	puts $fid "# fonts for each file type"
	puts $fid "# to specify/change font for a specific file type insert a line as follows;"
	puts $fid "# set editor(font,extension) {FontName FontSize}"
	foreach font [lsort [array names editor font*]] {
		puts $fid [list set editor($font) $editor($font)]
	}
	puts $fid ""

	puts $fid "# default extension (you'll need to edit file manually to change default extension)"
	puts $fid "set editor(default_ext) $editor(default_ext)"
	puts $fid ""
        

	close $fid

	# Close all files in reverse order... this is done so we don't end up displaying all files (see close_window)
	foreach name [lsort -dictionary -decreasing [array names editor *,status]] {
		set no [lindex [split $name ","] 0]
		if {$editor($no,status) != "CLOSED"} {
			if {![close_window $no "exit"]} {
				return
			}
		}
	}

	# Exit, close main window
	destroy .
}


#==== File-menu End ============================== #
#==== Walk_Tabs Begin ============================ #

proc make_window_active { editor_no } {
	global editor

	# Find current window and remove it from screen
	set current $editor(current)

	# Same file? Do nothing (return)
	if {$current == $editor_no} { return }

	if {$current != ""} {
		set w $editor($current,window)
		pack forget $w
		destroy .menu
	}

	# Get text widget window
	set t $editor($editor_no,text)

	# Title of window is "filename" (excluding drive/directory)
	wm title . $editor($editor_no,title)

	# Create main window menu
	menu .menu -tearoff 0

	# File menu
	set m .menu.file
	menu $m -tearoff 0
	.menu add cascade -label "File" -menu $m -underline 0
	$m add command -label "New" -command make_editor -underline 0
	$m add command -label "Open" -command "open_file $editor_no" -underline 0
	$m add command -label "Save" -command "save_file $editor_no" -underline 0 -accelerator Ctrl+S
	$m add command -label "Save As" -command "save_file_as $editor_no" -underline 5
	# If Windows, include print-option
	if {$::tcl_platform(platform) == "windows"} {
		$m add command -label "Print" -command "print_file $editor_no" -underline 0 -accelerator Ctrl+P
	}

	# All windows have close and exit function
	# Close window function closes window (unless main window, then clears window)
	# Exit function closes all windows then exits application
	$m add separator
	$m add command -label "Close Window" -underline 0 -command "close_window $editor_no"
	$m add separator
	$m add command -label "Exit ML EDITOR" -underline 1 -command "exit_editor"

	# Edit menu
	set m .menu.edit
	menu $m -tearoff 0
	.menu add cascade -label "Edit" -menu $m -underline 0
	$m add command -label "Undo" -command "$t undo" -underline 0 -accelerator Ctrl+Z
	$m add separator
	$m add command -label "Cut" -command "tk_textCut $t" -underline 0 -accelerator Ctrl+X
	$m add command -label "Copy" -command "tk_textCopy $t" -underline 0 -accelerator Ctrl+C
	$m add command -label "Paste" -command "tk_textPaste $t" -underline 0 -accelerator Ctrl+V

	# View menu
	set m .menu.view
	menu $m -tearoff 0
	.menu add cascade -label "View" -menu $m -underline 0
	$m add check -label "Goto Line" -command "goto_line $editor_no" -underline 0
	$m add check -label "Word Wrap" -command "toggle_word_wrap $editor_no" \
		-underline 0 -variable editor($editor_no,wordwrap) -onvalue 1 -offvalue 0
	$m add separator
	$m add command -label "Redraw Syntax" -command "syntax_highlight $editor_no 1 end" -underline 0
	$m add command -label "Toggle Syntax" -command "toggle_syntax" -underline 0
	$m add separator
	$m add command -label "Font Larger" -command "view_font_size $editor_no 1;update_status $editor_no" -underline 5 -accelerator Ctrl+Plus
	$m add command -label "Font Smaller" -command "view_font_size $editor_no -1;update_status $editor_no" -underline 5 -accelerator Ctrl+Minus

	# Search menu
	set m .menu.search
	menu $m -tearoff 0
	.menu add cascade -label "Search" -menu $m -underline 0
	
	# Following commands are duplicated below, see keyboard/accelerator bindings
	$m add command -label "Find ..." -accelerator Ctrl+F -command "search_find $editor_no" -underline 0
	$m add command -label "Find Next" -accelerator "F3" -command "search_find_next $editor_no" -underline 0
	$m add command -label "Find Prev" -accelerator "F4" -command "search_find_next $editor_no F4" -underline 0
	$m add command -label "Replace ..." -accelerator Ctrl+R -command "search_replace $editor_no" -underline 0
	$m add separator
	$m add command -label "Grep ..." -command "grep_search $editor_no" -underline 0

	# Window menu option
	set m .menu.window
	menu $m -tearoff 0 -postcommand "create_window_menu $m"
	.menu add cascade -label "Window" -menu $m -underline 0

	# Help menu option
	set m .menu.help
	menu $m -tearoff 0
	.menu add cascade -label "Help" -menu $m -underline 0
	$m add command -label "Brace-check" -command "brace_check $editor_no" -underline 0
	$m add command -label "About ML ..." -command about_window -underline 0

	. configure -menu .menu

	# map selected window
	set w $editor($editor_no,window)
	pack $w -expand yes -fill both

	# Save current editor number
	set editor(current) $editor_no

	# Has window been opened with syntax highlight?
	if {!$editor($editor_no,syntax)} {
		#puts "make_window_active is now doing syntax highlight"
		syntax_highlight $editor_no 1 end
	}

	if {$editor(just_launched)} {
		# Restore lastpos
		$t mark set insert $editor(lastpos)
		set editor(just_launched) 0
		$t see {insert -3 lines}

		update idletasks

		set editor(text_widget_height) [winfo height $t]
		set editor(bbox_height) [lindex [$t bbox @0,0] end]
	}

	# Put focus on text widget
	focus -force $t
	update_status $editor_no
}


# Called from make_window active
proc about_window {} {
	global editor

	set w .about

	# Destroy find-window if it already exists
	if {[winfo exists $w]} { destroy $w }

	# Create new find-window
	toplevel $w
	wm transient $w .
	wm title $w "About - ML Editor"

	label $w.1 -text "ML Text Editor v$editor(version)" -font {Arial 18 bold} -fg blue
	label $w.2 -anchor w -text "2025- SamuelKos github.com/SamuelKos" -font {Arial 11}
	label $w.3 -anchor w -text "To: Ruth and Eeva\n \"Ali\"" -font {Arial 9} -fg skyblue

	button $w.b -text "Close" -command "destroy $w"

	pack $w.1 $w.2 $w.3 $w.b -pady 5
	focus -force $w.b

	center_window $w
}


# Create window-menu with list of all open files
# Called from make_window_active
proc create_window_menu { m } {
	global editor

	# Remove all existing options
	$m delete 0 end

	# Starting menu item (1, 2, 3 ... A, B, C ...)
	set number 1

	foreach name [lsort -dictionary [array names editor *,file]] {
		set no [lindex [split $name ","] 0]
		if {$editor($no,status) != "CLOSED"} {
			if {$number < 10} {
				set item $number
			} else {
				set item [format "%2X" [expr {$number + 55}]]
				eval "set item \\\x$item"
			}
			if {$item <= "Z"} {
				$m add check -label "$item. $editor($no,title)" -command "make_window_active $no" \
					-underline 0 -variable editor($no,status) -onvalue $editor($no,status) -offvalue $editor($no,status) \
					-indicatoron [expr {$editor($no,status) == "MODIFIED"}]
			} else {
				$m add check -label "$editor($no,title)" -command "make_window_active $no" \
					-variable editor($no,status) -onvalue $editor($no,status) -offvalue $editor($no,status) \
					-indicatoron [expr {$editor($no,status) == "MODIFIED"}]
			}
			incr number
		}
	}
}


#==== Walk_Tabs End ============================= #
#==== __init__  Begin =========================== #

# Make new editor window and creates all necessary bindings
# Called at start-up to load files specified on command line and for every "file open"
proc make_editor { {file ""} {display_window 1} {highlight 0} } {
	global editor editor_no splash_status testrun mydata
	
	set w [frame .w[incr editor_no]]

	set editor($editor_no,window) $w
	set editor($editor_no,file) $file
	set editor($editor_no,title) [file tail $file]
	set editor($editor_no,status) ""
	set editor($editor_no,procs) ""
	set editor($editor_no,syntax) 0

	if {$file == ""} {
		set data ""
		set file "Untitled"
		# New files are always writable
		set editor($editor_no,writable) 1
		set editor($editor_no,data) $data

	} elseif {[catch {set fid [open $file]} msg]} {
		tk_messageBox -type ok -icon error -title "File Open Error" \
			-message "There was an error opening file \"$file\"; $msg."
		return
	} else {
		set data [read -nonewline $fid]
		close $fid
		set editor($editor_no,data) $data
		
		# Record whether or not file can be saved (is file writable?)
		set editor($editor_no,writable) [file writable $file]
		if {!$editor($editor_no,writable)} {
			set editor($editor_no,status) "READ ONLY"
		}
	}

	# Create main display frames (1 = editor, 2 = status/procedure window)
	set f1 [frame $w.f1]
	set f2 [frame $w.f2]

	#################################
	# Set string/name/windowpath for main text-widget,
	# Save it to variable: t
	set t $f1.text
	# Save it also to variable editor($editor_no,text) (so it can be globally referenced later)
	set editor($editor_no,text) $t
	#################################
	

	# Save file extension, used for syntax highlighting commands
	set editor($editor_no,extension) [string tolower [file extension $file]]

	set tx $f1.tx
	set ty $f1.ty

	# Has font been specified in ml_cfg.ml for this filetype?
	if {[array names editor font,$editor($editor_no,extension)] != ""} {
		set font $editor(font,$editor($editor_no,extension))
	} else {
		set font $editor(font)
	}


	set editor(tabwidth) [font measure $font "kkk"]
	set editor(pad) [expr {$editor(tabwidth)/3}]


	set cur "@cursor98.cur"
	if {$::tcl_platform(platform) != "windows"} {
		set cur ""
	}

	######################
	# Create text-widget #
	######################
	text $t -xscrollcommand "$tx set" -yscrollcommand "$ty set" -exportselection 1 \
			-wrap none -font $font -tabs "$editor(tabwidth)" -cursor $cur -background #e7e7e7

	$t insert end $data

	set editor($editor_no,wordwrap) 0
	
	scrollbar $tx -command "$t xview" -orient h
	scrollbar $ty -command "$t yview"
	if {!$testrun} {
		pack $tx -side bottom -fill x
		pack $ty -side right -fill y
		pack $t -side left -fill both -expand yes
	}


	##########################################


	bind $t <Alt-u> "update_status $editor_no;break"
	
	bind $t <Shift-Return> "comment_add $editor_no;break"
	bind $t <Shift-BackSpace> "comment_remove $editor_no;break"

	# Pass keysym to callback with %K
	bind $t <Control-Up> "move_manylines %W %K;break"
	bind $t <Control-Down> "move_manylines %W %K;break"
	bind $t <Control-j> "center_view $editor_no %K;break"
	bind $t <Control-u> "center_view $editor_no %K;break"
	bind $t <Control-J> "$t yview scroll 1 units;break"
	bind $t <Control-U> "$t yview scroll -1 units;break"
	bind $t <Return> "return_override %W;break"


	#bind $t <Control-O> "check_indent_depth %W;break"
	# OR:
	#bind $t <Control-O> "check_indent_depth \{[$t get 1.0 end]\};break"

	#bind $t <Control-O> "test_run $editor_no;break"
	#bind $t <Control-O> "brace_check $editor_no;break"
	
	
	bind $t <Tab> "indentation_add $editor_no;break"
	bind $t <Shift-Tab> "indentation_remove $editor_no;break"

	bind $t <Alt-a> "goto_linestart $editor_no;break"
	bind $t <Alt-e> "$t mark set insert {insert lineend};break"


	# Spaces to Tabs in indentation in curtab
	bind $t <F10> "replace_4_spaces $editor_no;break"


	# Convenience
	bind $t <Alt-c> "event generate $t <<Copy>>;break"
	bind $t <Alt-v> "event generate $t <<Paste>>;break"
	bind $t <Alt-x> "event generate $t <<Cut>>;break"
	bind $t <Alt-f> "search_find $editor_no;break"
	bind $t <Alt-r> "search_replace $editor_no;break"
	bind $t <Alt-l> "goto_line $editor_no;break"


	##########################################
	

	bind $t <Control-r> "search_replace $editor_no;break"
	bind $t <Control-f> "search_find $editor_no;break"
	bind $t <F3> "search_find_next $editor_no %K;break"
	bind $t <F4> "search_find_next $editor_no %K;break"

	bind $t <Control-l> "goto_line $editor_no;break"
	bind $t <Control-s> "save_file $editor_no;break"

##	if {$::tcl_platform(platform) == "windows"} {
##		bind $t <Control-p> "print_file $editor_no;break"
##	}

	bind $t <Control-plus> "view_font_size $editor_no 1;update_status $editor_no"
	bind $t <Control-minus> "view_font_size $editor_no -1;update_status $editor_no"

	# Mouse right: Select current word and display pop-up menu
	bind $t <ButtonPress-3> "popup_text_menu $editor_no %x %y"

	# Doubleclick braces to select code-blocks
	bind $t <Double-Button> {if {[select_block %W]} {break}}

	# Used in syntax_highlight
	$t tag configure command -foreground blue
	$t tag configure number -foreground DarkGreen
	$t tag configure proc -foreground blue -font {Verdana 9 bold}
	$t tag configure comment -foreground green4 ;#green4
	$t tag configure variable -foreground red
	$t tag configure quot -foreground purple
	$t tag configure sel -background skyblue
	$t tag configure sel -foreground black

	# Create proclist frame on the right
	text $f2.procs -xscrollcommand "$f2.tx set" -yscrollcommand "$f2.ty set" \
		-wrap none -font {Arial 8} -background #ffc800 -width 22 -cursor arrow
	
	set editor($editor_no,status_window) $f2.procs

	scrollbar $f2.tx -command "$f2.procs xview" -orient h
	scrollbar $f2.ty -command "$f2.procs yview"
	
	if {!$testrun} {
		pack $f2.tx -side bottom -fill x
		pack $f2.ty -side right -fill y
		pack $f2.procs -side left -fill both -expand yes
		
		# Pack frames
		pack $f1 -side left -fill both -expand yes
		pack $f2 -side left -fill y
	}
	
	focus -force $t
	$t mark set insert 1.0
	
	# When this happens? not at launch, not when opening file
	if {$highlight} {
		#puts "make_editor is now doing syntax highlight"
		syntax_highlight $editor_no 1 end
	}
	
	if {$display_window} {make_window_active $editor_no}
	
	$t configure -undo 1
	
	return $editor_no
}


#==== __init__  End =========================== #
#==== __main__  Begin ========================= #

package require Tk

global testrun
set testrun 0
if {[info exists argc] && $argc} {
	foreach name $argv {
		if {$name=="--debug"} {
		set testrun 1
		puts "\nTESTRUN BEGIN"
		break
		}
	}
}

##### Splash-screen Begin ###########################################
# init can take time --> indicate user that something is happening with splash-screen
if {!$testrun} {
	# To start things rolling display splash screen
	# See "Effective Tcl/Tk Programming" book, page 254-247 for reference
	wm withdraw .
	toplevel .splash -borderwidth 4 -relief raised
	wm overrideredirect .splash 1
	
	center_window .splash
	
	label .splash.info -text "https://github.com/SamuelKos" -font {Arial 9}
	pack .splash.info -side bottom -fill x
	
	label .splash.title -text "-- ML Editor Tcl/Tk --" -font {Arial 18 bold} -fg blue
	pack .splash.title -fill x -padx 8 -pady 8
	
	set splash_status "Initialiazing ..."
	label .splash.status -textvariable splash_status -font {Arial 9} -width 50 -fg darkred
	pack .splash.status -fill x -pady 8
	
	update
}
##### Splash-screen End #################################


##if {[catch "package require combobox"]} {source combobox.tcl}
source combobox.tcl

#############
global editor
#############

global editor_no
global file_types
global mydata
global tokens
global kwords
set kwords [lsort [info command]]

set editor(version) "1.13"
set editor(current) ""
set editor_no 0

# Set default file extension
set editor(default_ext) "tcl"
set editor(initial_dir) [pwd]
set editor(grep_path) $editor(initial_dir)

# Set default font - saved in ml_cfg.ml file (user need to change manually)
set editor(font) {Courier 9}

# Files loaded since last use of editor (see proc exit_editor)
set editor(file_history) {}

# Cursor position
set editor(lastpos) "1.0"
set editor(last_find_string) ""
set editor(just_launched) 1
set editor(pad) 1

# Find history (list of strings previously searched for)
set editor(find_history) {}
set editor(match_case) 0
set editor(replace_history) {}

# Do syntax by default
set editor(syntax) 1

# Load conf
if {!$testrun && [file readable "ml_cfg.ml"]} {
	source ml_cfg.ml
}

# Suggest last search string at next search
set editor(find_string) [lindex $editor(find_history) 0]
set editor(replace_string) [lindex $editor(replace_history) 0]

set file_types {
	{{All Files}	*	}
	{{TCL Scripts}	{.tcl}	}
	{{Text Files}	{.txt} }}


# Load files specified on command line
# If none then check "editor(file_history)" in conf

set any_files 0

if {!$testrun && $argc} {
	# Replace all backslashes with forward slashes for windows?
	# Needs check is this necessary
	regsub -all "\\\\" $name "/" name
	foreach name [glob -nocomplain $name] {
		make_editor $name 0 0
		set any_files 1
	}
	
} elseif {!$testrun && $editor(file_history) != ""} {
	foreach file $editor(file_history) {
		if {[file readable $file]} {
			make_editor $file 0 0
			set any_files 1
		}
	}
}


if {$any_files} {
	set splash_status "Loading $editor(1,title) ..."
	update
}

if {!$testrun} {
	after idle {
		destroy .splash
		wm deiconify .
	}
}

# Configure window and menus
configure_window
 
# make_editor is already called if there was command line arguments
# Or if there was configuration-file
# --> any_files 1
# If no files are loaded (if make_editor is not yet called),
# Then: open blank editor window (call make_editor)
if {!$any_files} {
	make_editor
} else {
	make_window_active 1
}

after 10000 syntax_check_loop

#==== __main__  End =========================== #














