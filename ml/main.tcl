# Note: have to be in same dir that contains main.tcl, this file

# Check first for: lassign existence
if {[lsearch [info commands] lassign] == -1 && [lsearch [info procs] lassign] == -1} {
	# Note: this is slow?
	proc lassign {valueList args} {
		if {[llength $args]==0} {error "wrong # args: lassign list varname ?varname..?"}
		
		if {[llength $valueList]==0} {
			# Ensure one trip through foreach loop
			set valueList [list {}]
		}
		uplevel 1 [list foreach $args $valueList {break}]
		return [lrange $valueList [llength $args] end]
	}
}

# Currently not using package require syntax, just sourcing from curdir
if {[catch {source ml.tcl}]} {
	global errorInfo
	puts "\nTraceback, raising call first."
	puts "Linenumbers for procs are counted from definition line:\n"
	puts stderr $errorInfo
	
	set chan [open err.txt w]
	puts $chan $errorInfo
	close $chan
	puts "\nerror is saved to: err.txt"
	exit
}






















