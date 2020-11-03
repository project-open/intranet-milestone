# /packages/intranet-milestone/www/milestone-list-component.tcl
#
# Copyright (c) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ---------------------------------------------------------------
# Variables
# ---------------------------------------------------------------

#    { end_date_before:integer "" }
#    { end_date_after:integer "" }
#    { project_id ""}
#    { cost_center_id ""}
#    { status_id ""}
#    { type_id ""}
#    { member_id ""}
#    { project_lead_id ""}


# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set current_user_id [auth::require_login]
set return_url [im_url_with_query]
set date_format "YYYY-MM-DD"

# ---------------------------------------------------------------
# Milestone List
# ---------------------------------------------------------------

set export_var_list [list]
set list_id "milestones_list_[string map {"." ""} [expr rand()]]"
set bulk_actions_list [list]
if {[im_permission $current_user_id "edit_projects_all"]} {
    lappend bulk_actions_list "Close" 
    lappend bulk_actions_list "/intranet-milestone/milestone-close"
    lappend bulk_actions_list "Close the selected milestones"
}

template::list::create \
    -name $list_id \
    -multirow milestone_lines \
    -key project_id \
    -has_checkboxes \
    -bulk_action_method GET \
    -bulk_actions $bulk_actions_list \
    -bulk_action_export_vars { return_url} \
    -row_pretty_plural "[lang::message::lookup "" intranet-milestone.Milestones {Milestones}]" \
    -elements {
	milestone_chk {
	    label "<input id=list_check_all type=\"checkbox\" name=\"_dummy\" title=\"Check/uncheck all rows\">"
	    display_template {
		@milestone_lines.milestone_chk;noquote@
	    }
	}
	project_on_track_status {
	    label "[lang::message::lookup {} intranet-milestone.On_track_status { }]"
	    display_template {
		@milestone_lines.on_track_html;noquote@
	    }
	}
	main_project_name {
	    label "[lang::message::lookup {} intranet-milestone.Project_Name {Project Name}]"
	    display_template {
		<a href=@milestone_lines.main_project_url;noquote@>@milestone_lines.main_project_name;noquote@</a> &nbsp;
	    }
	}
	project_name {
	    label "[lang::message::lookup {} intranet-milestone.Milestone_Name Name]"
	    display_template {
		<a href=@milestone_lines.milestone_url;noquote@>@milestone_lines.project_name;noquote@</a> &nbsp;
	    }
	}
        end_date_formatted {
	    label "[lang::message::lookup {} intranet-milestone.Deadline Deadline]"
	    display_template {
		@milestone_lines.end_date_formatted;noquote@ &nbsp;
	    }
	}
        project_type {
	    label "[lang::message::lookup {} intranet-milestone.Milestone_Type Type]"
	    display_template {
		@milestone_lines.project_type;noquote@ &nbsp;
	    }
	}
        project_status {
	    label "[lang::message::lookup {} intranet-milestone.Milestone_Status Status]"
	    display_template {
		@milestone_lines.project_status;noquote@ &nbsp;
	    }
	}
    }

# ---------------------------------------------------------------
# Compose SQL
# ---------------------------------------------------------------

set milestone_sql [im_milestone_select_sql \
	-end_date_before $end_date_before \
	-end_date_after $end_date_after \
	-type_id $type_id \
	-status_id $status_id \
	-member_id $member_id \
]

# ad_return_complaint 1 "<pre>$milestone_sql</pre>"

set sql "
	select	p.*,
		main_p.project_id as main_project_id,
		main_p.project_name as main_project_name,
		to_char(p.end_date, :date_format) as end_date_formatted
	from	($milestone_sql) p,
		im_projects main_p
	where	main_p.tree_sortkey = tree_root_key(p.tree_sortkey)
	order by
		main_p.project_name,
		p.end_date ASC
"

set cnt 0
db_multirow -extend {milestone_chk on_track_html milestone_url main_project_url return_url} milestone_lines milestones_lines $sql {
    set milestone_chk "<input type=\"checkbox\" 
				name=\"milestone_id\" 
				value=\"$project_id\" 
				id=\"milestone_id,$project_id\">"
    set return_url [im_url_with_query]
    set milestone_url [export_vars -base "/intranet/projects/view" {project_id}]
    set main_project_url [export_vars -base "/intranet/projects/view" {{project_id $main_project_id}}]
    set on_track_html [im_project_on_track_bb $on_track_status_id]
    incr cnt
}



