<if 0>
<%= [lang::message::lookup "" intranet-helpdesk.Milestones_in_interval "Milestones between now+$end_date_after and now+$end_date_before:"] %>
</if>


<script type="text/javascript" <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce;literal@"</if>>
window.addEventListener('load', function() { 
     document.getElementById('list_check_all').addEventListener('click', function() { acs_ListCheckAll('milestones_list', this.checked) });
});
</script>


<listtemplate name="@list_id@"></listtemplate>
<if @cnt@ gt 0>
</if>
