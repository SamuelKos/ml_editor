# Note: have to be in same dir that contains main.tcl, this file
# People might not have tclkit, so
# BBB

if {[catch {
	package require starkit
	starkit::startup
	package require app-ml
	}]} {source lib/app-ml/ml.tcl}








