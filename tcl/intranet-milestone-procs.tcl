# /packages/intranet-milestone/tcl/intranet-milestone-procs.tcl
#
# Copyright (C) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_library {
    @author frank.bergmann@project-open.com
}


# ----------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------

# im_milestone_type_id defined in intranet-projects-procs.tcl


# ----------------------------------------------------------------------
# PackageID
# ----------------------------------------------------------------------

ad_proc -public im_package_milestone_id {} {
    Returns the package id of the intranet-milestone module
} {
    return [util_memoize im_package_milestone_id_helper]
}

ad_proc -private im_package_milestone_id_helper {} {
    return [db_string im_package_core_id {
	select package_id from apm_packages
	where package_key = 'intranet-milestone'
    } -default 0]
}


# ----------------------------------------------------------------------
# Components
# ---------------------------------------------------------------------

ad_proc -public im_milestone_list_component {
    {-end_date_before "" }
    {-end_date_after "" }
    {-type_id ""}
    {-status_id ""}
    {-customer_id ""}
    {-member_id ""}
} {
    Returns a HTML component to show all project related milestone
} {
    set params [list \
		    [list return_url [im_url_with_query]] \
		    [list end_date_before $end_date_before] \
		    [list end_date_after $end_date_after] \
		    [list type_id $type_id] \
		    [list status_id $status_id] \
		    [list customer_id $customer_id] \
		    [list member_id $member_id] \
    ]
    set result [ad_parse_template -params $params "/packages/intranet-milestone/lib/milestone-list-component"]
    return [string trim $result]
}



ad_proc -public im_milestone_tracker {
    -project_id:required
    {-diagram_width 300 }
    {-diagram_height 300 }
    {-diagram_caption "" }
    {-diagram_title "Milestones" }
} {
    Returns a HTML code with a Sencha line diagram representing
    the evolution of the project's milestones (sub-projects marked
    as milestones or with a type that is a sub-type of milestone).
    @param project_id The project to show
} {
    # Check if audit has been installed
    if {![im_table_exists im_audits]} { return "" }

    # Check if the project is a main project and abort otherwise
    # We only want to show this diagram in a main project.
    set parent_id [db_string parent "select parent_id from im_projects where project_id = :project_id" -default ""]
    if {"" != $parent_id} { return "" }

    # Discard any projects without children
    set child_count [db_string child_count "select count(*) from im_projects where parent_id = :project_id" -default ""]
    if {0 == $child_count} { return "" }

    # Sencha check and permissions
    if {![im_sencha_extjs_installed_p]} { return "" }
    im_sencha_extjs_load_libraries

    # Call the lib portlet
    set params [list \
		    [list project_id $project_id] \
		    [list diagram_width $diagram_width] \
		    [list diagram_height $diagram_height] \
		    [list diagram_title $diagram_title] \
		    [list diagram_caption $diagram_caption] \
    ]
    set result [ad_parse_template -params $params "/packages/intranet-milestone/lib/milestone-tracker"]
    return [string trim $result]
}



# ----------------------------------------------------------------------
# Generate generic select SQL for milestones
# to be used in list pages, options, ...
# ---------------------------------------------------------------------

ad_proc -public im_milestone_select_sql { 
    {-type_id ""} 
    {-end_date_before "" }
    {-end_date_after "" }
    {-status_id ""} 
    {-customer_id ""}
    {-member_id ""} 
    {-cost_center_id ""} 
    {-var_list "" }
} {
    Returns an SQL statement that allows you to select a range of
    milestones, given a number of conditions.
    The variable names returned by the SQL adhere to the ]po[ coding
    standards. Important returned variables include:
	- im_projects.*, (all fields from the Projects table)
	- milestone_status, milestone_type, (status and type human readable)
} {
    set current_user_id [ad_conn user_id]
    array set var_hash $var_list
    foreach var_name [array names var_hash] { set $var_name $var_hash($var_name) }

    if {![string is integer $end_date_before]} { ad_return_complaint 1 "end_date_before is not an integer: '$end_date_before'" }
    if {![string is integer $end_date_after]} { ad_return_complaint 1 "end_date_after is not an integer: '$end_date_after'" }

    set extra_froms [list]
    set extra_wheres [list]

    if {"" != $member_id} {
	lappend extra_wheres "owner_rel.object_id_one = p.project_id"
	lappend extra_wheres "(owner_rel.object_id_two = :member_id)"
	lappend extra_froms "acs_rels owner_rel"
    }

    # -----------------------------------------------
    # Permissions

    set perm_where "
	p.project_id in (
		-- User is explicit member of project
		select	p.project_id
		from	im_projects p,
			acs_rels r
		where	r.object_id_two = [ad_conn user_id] and
			r.object_id_one = p.project_id
	UNION
		-- User belongs to a company which is the customer of project that belongs to milestome
		select	p.project_id
		from	im_companies c,
			im_projects p,
			acs_rels r1,
			acs_rels r2
		where	r1.object_id_two = [ad_conn user_id] and
			r1.object_id_one = c.company_id and
			p.company_id = c.company_id
	)
    "

    if {[im_permission $current_user_id "view_projects_all"]} { set perm_where "" }

    # -----------------------------------------------
    # Join the query parts

    if {"" != $status_id} { lappend extra_wheres "p.project_status_id in ([join [im_sub_categories $status_id] ","])" }
    if {"" != $type_id} { lappend extra_wheres "p.project_type_id in ([join [im_sub_categories $type_id] ","])" }
    if {"" != $perm_where} { lappend extra_wheres $perm_where }

    if {"" != $end_date_after} { lappend extra_wheres "p.end_date >= now()+'$end_date_after days'" }
    if {"" != $end_date_before} { lappend extra_wheres "p.end_date < now()+'$end_date_before days'" }

    set extra_from [join $extra_froms "\n\t\t,"]
    set extra_where [join $extra_wheres "\n\t\tand "]

    if {"" != $extra_from} { set extra_from ",$extra_from" }
    if {"" != $extra_where} { set extra_where "and $extra_where" }

    set select_sql "
	select distinct
		p.*,
		im_category_from_id(project_status_id) as project_status,
		im_category_from_id(project_type_id) as project_type
	from
		im_projects p
		$extra_from
	where
		(	p.milestone_p = 't' OR 
			p.project_type_id in ([join [im_sub_categories [im_project_type_milestone]] ","])
		)
		$extra_where
    "

    return $select_sql
}


