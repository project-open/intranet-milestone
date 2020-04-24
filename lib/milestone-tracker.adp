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
	// This is important so that the diagram doesn't show the audit points after
	// a phase has been finished.
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
    
    // Should we have some days before and after the actual lines?
    var marginTime = 0 * 24 * 3600 * 1000;		// N * days (milliseconds)

    // The store of with milestone data. Calculated by TCL back-end
    var milestoneStore = Ext.create('Ext.data.JsonStore', {
        fields: @fields_json;noquote@,
        data: @data_json;noquote@
    });

    // The store with baselines and a line for "today"
    var baselineStore = @baseline_store_json;noquote@;

    var chart = new Ext.chart.Chart({
        renderTo: '@diagram_id@',
        width: @diagram_width@,
        height: @diagram_height@,
        animate: false,
        store: milestoneStore,
        legend: { 
            position: 'float'
        },
        axes: [{
            type: 'Time',
	    title: '@milestone_end_date_l10n@',
            position: 'left',
            fields: [@fields_joined;noquote@],
            // dateFormat: 'j M y',
            dateFormat: 'Y-m-d',
            constrain: false,
            step: [@yrange_step_uom@, @yrange_step_units@],
            fromDate: @yrange_start_date_js;noquote@,
            toDate: @yrange_end_date_js;noquote@,
        }, {
            type: 'Time',
	    title: '@date_of_planning_l10n@',
            position: 'bottom',
            fields: 'date',
            // dateFormat: 'j M y',
            dateFormat: 'Y-m-d',
            constrain: false,
            step: [@tracker_step_uom@, @tracker_step_units@],
            fromDate: new Date(@tracker_start_date_js;noquote@.getTime() - marginTime),
            toDate: new Date(@tracker_end_date_js;noquote@.getTime() + marginTime),
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
        },
        /**                                                                                                                                                     
         * Convert a date into an X position, relative to the left of the surface.
         */
        date2x: function(d) {
            var me = this;
            if (me.debugAxis) console.log('PO.milestone.MilestoneChart.date2x('+d+'): Starting');
            
            var surfaceHeight = me.surface.height;
            var surfaceWidth = me.surface.width;
            
            var xAxis = me.axes.map["bottom"];
            var yAxis = me.axes.map["left"];

            var xStart = xAxis.x;
            var xEnd = xAxis.x + xAxis.length;

            var fromDate = xAxis.fromDate.getTime();
            var toDate = xAxis.toDate.getTime();
	    var diffDate = Math.abs(1.0*toDate - 1.0*fromDate);
	    if (diffDate < 1.0) return null;
            var dDate = d.getTime();
            var perc = (dDate - fromDate) / (toDate - fromDate);
            return xStart + (xEnd - xStart) * perc;

            if (me.debugAxis) console.log('PO.milestone.MilestoneChart.date2x: Finished');
        },

        /**
         * Draw a red vertical bar to indicate where we are today
         */
        drawBaselines: function() {
            var me = this;
            var surfaceWidth = me.surface.width;
            var surfaceHeight = me.surface.height;
            var axisHeight = 10;

            var xAxis = me.axes.map["bottom"];
            var yAxis = me.axes.map["left"];

            var xStart = xAxis.x;
            var xEnd = xAxis.x + xAxis.length;

            var labelY = yAxis.y - yAxis.length;

            baselineStore.each(function(model) {
                var creation_date = model.get('creation_date');
		if (!creation_date) return;
                var dateX = me.date2x(new Date(creation_date));
		if (null === dateX) return;

		console.log(model);
                var baselineLine = me.surface.add({
                    type:'rect', 
                    x: dateX, 
                    y: yAxis.y - yAxis.length,
                    width: 0.5, 
                    height: yAxis.length,
                    stroke:'#FF0000', 
                    zIndex: 200
                }).show(true);

                var axisText = me.surface.add({
                    type: 'text',
                    text: model.get('baseline_name') +"\n"+model.get('creation_date'),
                    x: dateX + 5,
                    y: labelY,
//		    stroke:'#FF0000',
                    fill: '#FF0000',
                    font: "10px Arial"
                }).show(true);

		labelY = labelY + 30;
		if (labelY > yAxis.y) { labelY = yAxis.y - yAxis.length; }

            });
        }
    });
    chart.drawBaselines();

});
</script>


<if "1" eq @show_debug_p@>
@debug_html;noquote@
</if>
</if>

