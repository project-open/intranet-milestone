<if "1" eq @show_diagram_p@>
<div id=@diagram_id@></div>
<script type='text/javascript'>

// Special variant of a line series for milestone tracker...
// ... that actually skips "undefined" values in the store.
Ext.define('Ext.chart.series.MilestoneLine', {
    extend: 'Ext.chart.series.Line',
    type: 'milestoneline',
    alias: 'series.milestoneline',

    drawSeries: function() {
	var me = this,
        chart = me.chart,
        store = chart.getChartStore();

	// Loop throught the store and convert empty strings into "undefined" values.
	// Undefined values are skipped by the underlying series.Line diagram.
	store.each(function(record) {
	    for (var key in record.data) {
		var value = record.data[key];
		if ("string" == typeof value && "" == value) { record.data[key] = undefined; }
	    }
	});

	// Call the basic drawSeries(), now skipping empty values
        this.callParent(arguments);
    }
});

Ext.require(['Ext.chart.*', 'Ext.Window', 'Ext.fx.target.Sprite', 'Ext.layout.container.Fit']);
Ext.onReady(function () {

    var store = Ext.create('Ext.data.JsonStore', {
	fields: @fields_json;noquote@,
	data: @data_json;noquote@
    });

    chart = new Ext.chart.Chart({
	width: 600,
	height: 300,
	animate: false,
	store: store,
	renderTo: '@diagram_id@',
	legend: { position: 'right' },
	axes: [{
	    type: 'Time',
	    position: 'left',
	    fields: [@fields_joined;noquote@],
	    dateFormat: 'M Y',
	    constrain: false,
	    step: [Ext.Date.MONTH, @yrange_step_months@],
	    fromDate: @yrange_start_date_js;noquote@,
	    toDate: @yrange_end_date_js;noquote@,
	}, {
	    type: 'Time',
	    position: 'bottom',
	    fields: 'date',
	    dateFormat: 'M Y',
	    constrain: false,
	    step: [Ext.Date.MONTH, @tracker_step_months@],
	    fromDate: @tracker_start_date_js;noquote@,
	    toDate: @tracker_end_date_js;noquote@,
	    label: {rotate: {degrees: 315}}
	}],
	series: [@series_json;noquote@]
    }
)});
</script>


<if "1" eq @show_debug_p@>
@debug_html;noquote@
</if>
</if>

