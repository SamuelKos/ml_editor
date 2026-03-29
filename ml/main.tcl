# Note: have to be in same dir that contains main.tcl, this file
# People might not have tclkit, so

if {[catch {
	package require starkit
	starkit::startup
	package require app-ml
	} err]} {

	# there is no starkit package
	if {[string first "find package" $err ] != -1} {
	#puts "no starpak"
	
	# it seems that starkit package contains definition for lassign,
	# if not have starkit, must use own lassign
	proc lassign {valueList args} {
		if {[llength $args]==0} {
			error "wrong # args: lassign list varname ?varname..?"
		}
		
		if {[llength $valueList]==0} {
			# ensure one trip through foreach loop
			set valueList [list {}]
		}
		uplevel 1 [list foreach $args $valueList {break}]
		return [lrange $valueList [llength $args] end]
	}

	if {[catch {source lib/app-ml/ml.tcl}]} {
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

	} else {
	#puts "yes starpak but errors"
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
	

}





















