<if "1" eq @show_diagram_p@>
<div id=@diagram_id@></div>
<script type='text/javascript'>

Ext.require([
    'Ext.chart.*', 
    'Ext.Window', 
    'Ext.fx.target.Sprite', 
    'Ext.layout.container.Fit'
]);

// Special variant of a line series for milestone tracker...
// ... that actually skips "undefined" values in the store.
Ext.define('Ext.chart.series.MilestoneLine', {
    extend: 'Ext.chart.series.Line',
    type: 'milestoneline',
    alias: 'series.milestoneline',

    drawSeries: function() {
	var me = this;
        var chart = me.chart;
        var store = chart.getChartStore();

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

Ext.onReady(function () {

    var store = Ext.create('Ext.data.JsonStore', {
	fields: @fields_json;noquote@,
	data: @data_json;noquote@
    });

    var chart = new Ext.chart.Chart({
	renderTo: '@diagram_id@',
	width: @diagram_width@,
	height: @diagram_height@,
	animate: false,
	store: store,
	legend: { 
	    position: 'float'
	},
	axes: [{
	    type: 'Time',
	    position: 'left',
	    fields: [@fields_joined;noquote@],
	    dateFormat: 'j M y',
	    constrain: false,
	    step: [@yrange_step_uom@, @yrange_step_units@],
	    fromDate: @yrange_start_date_js;noquote@,
	    toDate: @yrange_end_date_js;noquote@,
	}, {
	    type: 'Time',
	    position: 'bottom',
	    fields: 'date',
	    dateFormat: 'j M y',
	    constrain: false,
	    step: [@tracker_step_uom@, @tracker_step_units@],
	    fromDate: @tracker_start_date_js;noquote@,
	    toDate: @tracker_end_date_js;noquote@,
	    label: {rotate: {degrees: 315}}
	}],
	series: [@series_json;noquote@],
	listeners: {
    	    boxready: function(myChart, chartWidth, chartHeight, eOpts) {
		// Determine new position of legend in lower right corner
	        var myLegend = myChart.legend;
		var legendHeight = myLegend.height;
		var legendWidth = myLegend.width;
		var xAxis = myChart.axes.get('bottom');
		myLegend.origX = @diagram_width@ - legendWidth - 20;
		myLegend.origY = xAxis.y - legendHeight - 20;

		var legendBBox = {
		    x: myLegend.origX,
		    y: myLegend.origY,
		    width: legendWidth,
		    height: legendHeight
		};

		// Check if any coordinates are within legend box
		myLegend.toggle(false); 		         // Hide the legend for the comparison
		var surface = myChart.surface;
		var intersection = false;
		surface.items.items.forEach(function(item) {
		    if (item.type === "text") return;		// Skip the text items inside the legend
		    var itemBBox = item.getBBox();
		    if (itemBBox.width > 20) return;		// Skip any _path_ (not icon)
		    if (itemBBox.height > 20) return;		// Skip any _path_ (not icon)
		    
		    if (!(					// Check if item intersects with legend
			itemBBox.x > legendBBox.x + legendBBox.width || 
			itemBBox.x + itemBBox.width  < legendBBox.x || 
			itemBBox.y > legendBBox.y + legendBBox.height ||
			itemBBox.y + itemBBox.height < legendBBox.y
		    )) intersection = true;
		});

		if (myLegend.y >= 0 && !intersection) {     // Hide if legend doesn't fit or if it intersects with diagram
		    myLegend.toggle(true); 		    // Better hide than ugly
		    myLegend.updatePosition();
		}
	    }
	}
    });

});
</script>


<if "1" eq @show_debug_p@>
@debug_html;noquote@
</if>
</if>

