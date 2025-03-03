# /packages/intranet-milestone/lib/milestone-tracker.tcl
#
# Copyright (C) 2012 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

# ----------------------------------------------------------------------
# 
# ---------------------------------------------------------------------

# The following variables are expected in the environment
# defined by the calling /tcl/*.tcl libary:
#	project_id
#	diagram_title
#	diagram_width
#	diagram_height

if {![info exists diagram_width]} { set diagram_width 600 }
if {![info exists diagram_height]} { set diagram_height 300 }
if {![info exists diagram_name_maxlen]} { set diagram_name_maxlen 30 }
set main_project_id $project_id

# Create a random ID for the diagram
set diagram_rand [expr round(rand() * 100000000.0)]
set diagram_id "milestone_tracker_$diagram_rand"
set show_diagram_p 1
set show_debug_p 0

set audit_dates_max_entries 15


# -----------------------------------------------------------------
# Localization
# -----------------------------------------------------------------

set milestone_end_date_l10n [lang::message::lookup "" intranet-milestone.Milestone_End_Date "Milestone End Date"]
set date_of_planning_l10n [lang::message::lookup "" intranet-milestone.Date_of_Planning "Date of Planning"]
set milestone_l10n [lang::message::lookup "" intranet-milestone.Milestone "Milestone"]


# -------------------------------------------------------------
# Get information about the project
# -------------------------------------------------------------

db_1row project_info "
	select	start_date::date as project_start_date,
		end_date::date as project_end_date
	from	im_projects p
	where	p.project_id = :main_project_id
"

# -------------------------------------------------------------
# Compile the list of milestones to be reported
# -------------------------------------------------------------

# Check if there is at least one correctly defined
# milestone in the project.
set milestone_ptypes [im_sub_categories [im_project_type_milestone]]
set milestone_list [db_list milestone_list "
	select	child.project_id
	from	im_projects parent, 
		im_projects child 
	where	parent.project_id = :main_project_id and 
		child.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey) and
		(child.milestone_p = 't' OR child.project_type_id in ([join $milestone_ptypes ","]))
"]

if {[llength $milestone_list] < 1} {
    # We didn't find at least 3 "real" milestones in the project.
    # Try using the project "phases" (1st level task right below
    # the main projects.
    set milestone_list [db_list milestone_list "
	select	child.project_id
	from	im_projects parent, 
		im_projects child 
	where	parent.project_id = :main_project_id and 
		child.parent_id = parent.project_id and
		child.project_type_id not in ([im_project_type_ticket])
    "]
}


if {"" eq $milestone_list} { set milestone_list {0} }
if {[llength $milestone_list] < 1} { set show_diagram_p 0 }
foreach mid $milestone_list {
    set name [acs_object_name $mid]
    if {[string length $name] > $diagram_name_maxlen} {
	set name "[string range $name 0 $diagram_name_maxlen]..."
    }
    set milestone_name_hash($mid) $name
}


# -------------------------------------------------------------
# Compile the dates on which we want to report
# -------------------------------------------------------------

# Get the list of distinct dates when changes have ocurred
set audit_julians_sql "
	select distinct
		to_char(audit_date, 'J') as audit_julian
	from	im_audits a
	where	a.audit_object_id in ([join $milestone_list ","])
	order by to_char(audit_date, 'J')
"
set audit_julians [db_list audit_julians $audit_julians_sql]

# Algorithm to reduce the number of horizontal data points:
# Check for the shortest interval between dates and remove this entry
set max_cnt [llength $audit_julians]
while {$max_cnt > 0 && [llength $audit_julians] > $audit_dates_max_entries} {

    set last_date [lindex $audit_julians 0]
    set lowest_diff 100000
    set lowest_diff_idx -1
    # Exclude the first and the last element of the audit_julians list
    for {set j 1} { $j < [expr [llength $audit_julians] - 1]} {incr j} {
	set val [lindex $audit_julians $j]
	set diff [expr $val - $last_date]
	if {$diff < $lowest_diff} {
	    set lowest_diff $diff
	    set lowest_diff_idx $j
	}
	set last_date $val
    }
    ns_log Notice "milestone-tracker.tcl: max_cnt=$max_cnt: lowest_diff=$lowest_diff, lowest_diff_idx=$lowest_diff_idx in $audit_julians"
    set audit_julians [lreplace $audit_julians $lowest_diff_idx $lowest_diff_idx]
    ns_log Notice "milestone-tracker.tcl: max_cnt=$max_cnt: new audit_julians= $audit_julians"

    incr max_cnt -1
}

set diff_list [list]
set audit_dates [list]
set last_j [lindex $audit_julians 0]
foreach j $audit_julians {
    lappend audit_dates [dt_julian_to_ansi $j]
    set diff [expr $j - $last_j]
    lappend diff_list $diff
    set last_j $j

}

if {"" eq $audit_dates} {
    set show_diagram_p 0
    return
}

# ad_return_complaint 1 "milestone_list=$milestone_list, show_diagram_p=$show_diagram_p"




# -----------------------------------------------
# Determine Start- and End date for the Tracker
#
set tracker_start_date [lindex $audit_dates 0]
set tracker_end_date [lindex $audit_dates end]
set yrange_start_date $tracker_start_date
set yrange_end_date $tracker_end_date
set today [db_string today "select now()::date"]

# Initialize the maximum end_date per milestone
foreach mid $milestone_list {
    set milestone_end_date_hash($mid) "2000-01-01"
}


# Show the today bar only if within the display area
set show_today_p 1
if {$today < $tracker_start_date} { set show_today_p 0 }
if {$today > $tracker_end_date} { set show_today_p 0 }


if {[llength $audit_dates] < 1} { set show_diagram_p 0 }



if {0} {
    ad_return_complaint 1 "<table>
	<tr><td>diff_list=[join $diff_list "</td><td>"]</td></tr>
	<tr><td>audit_dates=[join $audit_dates "</td><td>"]</td></tr>
	</table>"
    ad_page_abort
}




# -------------------------------------------------------------
# Gather the data to be displayed
# -------------------------------------------------------------

# Get the "hard" cell value points from the audit
set cell_sql "
	select	a.audit_object_id,
		a.audit_date::date as audit_date,
		substring(im_audit_value(a.audit_value, 'start_date') for 10) as start_date,
		substring(im_audit_value(a.audit_value, 'end_date') for 10) as end_date
	from	im_audits a
	where	a.audit_date::date in ('[join $audit_dates "','"]') and
		a.audit_object_id in ([join $milestone_list ","])
	order by
		a.audit_object_id,
		a.audit_date
"
db_foreach cells $cell_sql {
    if {"" eq $start_date || "" eq $end_date} { continue }
    set key "$audit_object_id-$audit_date"
    set cell_hash($key) [string range $end_date 0 9]

    # Calculate the maximum values for X and Y axis
    if {$start_date < $yrange_start_date} { set yrange_start_date $start_date }
    if {$end_date > $yrange_end_date} { set yrange_end_date $end_date }

    # Find max(end_date) of the milestone
    if {$end_date > $milestone_end_date_hash($audit_object_id)} { set milestone_end_date_hash($audit_object_id) $end_date }
}



# Extrapolate the cell values for audit_dates that don't have data
set audit_dates_rev [lreverse $audit_dates]
foreach oid $milestone_list {

    # Roll values along the time axis towards cells without values
    set end_date ""
    foreach d $audit_dates {
	set key "$oid-$d"
	if {[info exists cell_hash($key)]} {
	    set end_date $cell_hash($key)
	} else {
	    if {"" ne $end_date} { set cell_hash($key) $end_date }
	}
    }

    # There may be empty values in the beginning of the report interval
    # So now go against the time axis and fill those holes with the future value
    set end_date ""
    foreach d $audit_dates_rev {
	set key "$oid-$d"
	if {[info exists cell_hash($key)]} {
	    set end_date $cell_hash($key)
	} else {
	    if {"" ne $end_date} { set cell_hash($key) $end_date }
	}
    }
}
# now the cell_hash should have a value for every oid / date combination
# ad_return_complaint 1 [array get cell_hash]


regexp {^(....)\-(..)\-(..)$} $tracker_start_date match year month day
set tracker_start_date_js "new Date('$year-$month-$day')"
regexp {^(....)\-(..)\-(..)$} $tracker_end_date match year month day
set tracker_end_date_js "new Date('$year-$month-$day')"

regexp {^(....)\-(..)\-(..)$} $yrange_start_date match year month day
set yrange_start_date_js "new Date('$year-$month-$day')"
regexp {^(....)\-(..)\-(..)$} $yrange_end_date match year month day
set yrange_end_date_js "new Date('$year-$month-$day')"



set tracker_start_julian [dt_ansi_to_julian_single_arg $tracker_start_date]
set tracker_end_julian [dt_ansi_to_julian_single_arg $tracker_end_date]
set tracker_duration_days [expr $tracker_end_julian - $tracker_start_julian]
set tracker_duration_months [expr $tracker_duration_days / 30.0]
set tracker_step_months [expr 1 + int($tracker_duration_months / 10.0)]

# Determine step-width for the Y range:
set tracker_days [expr $tracker_end_julian - $tracker_start_julian]
if {1} {
    # more than 10 years
    set tracker_step_uom "Ext.Date.YEAR"
    set tracker_step_units 1
    set tracker_date_format "Y-m"
}
if {$tracker_days < 3650} {
    # between 5 months and 10 years
    set tracker_step_uom "Ext.Date.MONTH"
    set tracker_step_units [expr int($tracker_days / 250)]
    if {$tracker_step_units < 1} { set tracker_step_units 1 }
    set tracker_date_format "Y-m"
}
if {$tracker_days < 132} {
    # less than 4 months
    set tracker_step_uom "Ext.Date.DAY"
    set tracker_step_units [expr int($tracker_days / 15)]
    if {$tracker_step_units < 1} { set tracker_step_units 1 }
    set tracker_date_format "Y-m-d"
}


# Y-Range
set yrange_start_julian [dt_ansi_to_julian_single_arg $yrange_start_date]
set yrange_end_julian [dt_ansi_to_julian_single_arg $yrange_end_date]
set yrange_duration_days [expr $yrange_end_julian - $yrange_start_julian]
set yrange_duration_months [expr $yrange_duration_days / 30.0]
set yrange_step_months [expr 1 + int($yrange_duration_months / 10.0)]

# Determine step-width for the Y range:
set yrange_days [expr $yrange_end_julian - $yrange_start_julian]
if {1} {
    # more than 10 years
    set yrange_step_uom "Ext.Date.YEAR"
    set yrange_step_units 1
    set yrange_date_format "Y-m"
}
if {$yrange_days < 3650} {
    # between 5 months and 10 years
    set yrange_step_uom "Ext.Date.MONTH"
    set yrange_step_units [expr int($yrange_days / 250)]
    if {$yrange_step_units < 1} { set yrange_step_units 1 }
    set yrange_date_format "Y-m"
}
if {$yrange_days < 33} {
    set yrange_step_uom "Ext.Date.DAY"
    set yrange_step_units [expr int($yrange_days / 15)]
    if {$yrange_step_units < 1} { set yrange_step_units 1 }
    set yrange_date_format "Y-m-d"
}



# ad_return_complaint 1 $yrange_duration_months



# -----------------------------------------------------------------
# Store with Baselines
# -----------------------------------------------------------------

if {[im_table_exists im_baselines]} {

    set baseline_sql_today "
	UNION
		select	0 as baseline_id,
			'Today' as baseline_name,
			null as baseline_status,
			null as baseline_type,
			now()::date as creation_date
    "
    if {!$show_today_p} { set baseline_sql_today "" }

    set baseline_sql "
	select	t.*
	from	(select	b.baseline_id,
			b.baseline_name,
			im_category_from_id(b.baseline_status_id) as baseline_status,
			im_category_from_id(b.baseline_type_id) as baseline_type,
			o.creation_date::date as creation_date
		from
			im_baselines b,
			acs_objects o
		where
			b.baseline_project_id = $main_project_id and
			b.baseline_id = o.object_id
			$baseline_sql_today
		 ) t
	order by baseline_id DESC
    "
    set baseline_store_tuple [im_sencha_sql_to_store -sql $baseline_sql]
    set baseline_store_json [lindex $baseline_store_tuple 0]
    set baseline_store_columns [lindex $baseline_store_tuple 1]

#    ad_return_complaint 1 "baseline_sql_today=$baseline_sql_today<br>baseline_store_json=$baseline_store_json<br><pre>$baseline_sql</pre><br>show_today_p=$show_today_p"
} else {

    set baseline_store_tuple [im_sencha_sql_to_store -sql "select 1 where 1=0"]
    set baseline_store_json [lindex $baseline_store_tuple 0]
    set baseline_store_columns [lindex $baseline_store_tuple 1]
}

# -----------------------------------------------------------------
# Format the data JSON and HTML
# -----------------------------------------------------------------

set debug_html "<table>"

# Header row
set row "<td class=rowtitle>Date</td>"
foreach mid $milestone_list {
    set milestone_name $milestone_name_hash($mid)
    set milestone_url [export_vars -base "/intranet/projects/view" {{project_id $mid}}]
    append row "<td class=rowtitle><a href=$milestone_url target=_blank>$milestone_name</a></td>\n"
}
append debug_html "<tr class=rowtitle>$row</tr>\n"

# Loop through all available audit records and write out data and HTML lines
set cnt 0
foreach audit_date $audit_dates {

    # Reformat date for javascript
    regexp {^(....)\-(..)\-(..)$} $audit_date match audit_year audit_month audit_day
    set data_line "{date: new Date('$audit_year-$audit_month-$audit_day'), horizon: new Date('$audit_year-$audit_month-$audit_day')"

    # Loop through the columns
    set row "<td><nobr>$audit_date</nobr></td>"
    foreach mid $milestone_list {
	set key "$mid-$audit_date"
	set series_v ""
	if {[info exists cell_hash($key)]} { set series_v $cell_hash($key) }
	if {"" eq $series_v} { continue }
	regexp {^(....)\-(..)\-(..)$} $series_v match series_year series_month series_day
	# ns_log Notice "milestone-tracker.tcl: mid=$mid, series_v=$series_v, match=$match"
	set series_v_js "new Date('$series_year-$series_month-$series_day')"

	# Skip values of milestones after they have been closed
	# Exception: The very first entry in order to show something in case of demo data etc.
	set milestone_max_end_date $milestone_end_date_hash($mid)
	if {0 != $cnt && $audit_date > $milestone_max_end_date} {
	    set series_v_js "undefined"
	    set series_v "undefined"
	}

	append data_line ", m$mid: $series_v_js"
	append row "<td><nobr>$series_v</nobr></td>\n"
    }
    append data_line "}"
    lappend data_list $data_line

    append debug_html "<tr class=rowtitle>$row</tr>\n"
    incr cnt
}
append debug_html "</table>"
#ad_return_complaint 1 $debug_html
#ad_return_complaint 1 $data_list


# Compile JSON for data
set data_json "\[\n"
append data_json "\t\t[join $data_list ",\n\t\t"]"
append data_json "\t\]\n"



# Compile JSON for field names
set fields {}
lappend fields "'horizon'"
foreach mid $milestone_list {
    lappend fields "'m$mid'"
}
set fields_joined [join $fields ", "]
set fields_json "\['date', $fields_joined\]"


# ad_return_complaint 1 $fields_joined
# ad_return_complaint 1 "<pre>$fields_json\n\n$data_json</pre>"

# Complile the series specs
set series {}

lappend series "{
	type: 'line', 
	title: 'Horizon', 
	axis: \['left','bottom'\], 
	xField: 'date', 
	yField: 'horizon', 
        showInLegend: false,
	markerConfig: { radius: 0, size: 0 }
}"


foreach id $milestone_list {
    set milestone_name $milestone_name_hash($id)
    lappend series "{
	type: 'milestoneline', 
        title: '$milestone_name', 
        axis: \['left','bottom'\], 
        xField: 'date', 
        yField: 'm$id', 
        markerConfig: { radius: 5, size: 5 },
        tips: {
            trackMouse: false,
            anchor: 'right',
            width: 250,
            height: 60,
            renderer: function(storeItem, item) {
                var seriesTitle = item.series.title;
                var seriesYField = item.series.yField;
                var xDate = storeItem.get('date').toISOString().split('T')\[0\];
                var yDate = storeItem.get(seriesYField).toISOString().split('T')\[0\];
                this.setTitle(
			'$milestone_l10n: '+seriesTitle+
			'<br>$date_of_planning_l10n: '+xDate+ 
			'<br>$milestone_end_date_l10n: '+yDate
		);
            }
        }
    }
    "
}
set series_json [join $series ", "]

# ad_return_complaint 1 $fields_joined
# ad_return_complaint 1 "<pre>$fields_json\n\n$data_json</pre>"




