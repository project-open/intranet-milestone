<if "1" eq @show_diagram_p@>
<!--
<ul>
<li>tracker_days: @tracker_days@
<li>tracker_step_uom: @tracker_step_uom@
<li>tracker_step_units: @tracker_step_units@
</li>
-->
<div id=@diagram_id@></div>
<script type='text/javascript'>

Ext.Loader.setPath('PO', '/sencha-core');

Ext.require([
    'Ext.chart.*', 
    'Ext.Window', 
    'Ext.fx.target.Sprite', 
    'Ext.layout.container.Fit',
    'PO.view.menu.HelpMenu'
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

    // Where do we find GIFs?
    var gifPath = "/intranet/images/navbar_default/";

    // The store of with milestone data. Calculated by TCL back-end
    var milestoneStore = Ext.create('Ext.data.JsonStore', {
        fields: @fields_json;noquote@,
        data: @data_json;noquote@
    });

    // The store with baselines and a line for "today"
    var baselineStore = @baseline_store_json;noquote@;

    var chart = new Ext.chart.Chart({
        debug: true,
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
            dateFormat: '@yrange_date_format@',
            constrain: false,
            step: [@yrange_step_uom@, @yrange_step_units@],
            fromDate: @yrange_start_date_js;noquote@,
            toDate: @yrange_end_date_js;noquote@,
            label: {
                // Work around bug in Sencha TimeAxis with Month scale showing 31st of last month
                renderer: function(value, label, storeItem, item, i, display, animate, index) { 
                    var valueDate = new Date(value);
                    var valueDay = valueDate.getDate();
                    while (valueDay > 25 && "Ext.Date.MONTH" === '@tracker_step_uom@') {
                        valueDate = new Date(valueDate.getTime() + 24.0*3600.0*1000.0); // add one day
                        valueDay = valueDate.getDate();
                    }
                    return valueDate.getTime(); 
                }
            }
        }, {
            type: 'Time',
            title: '@date_of_planning_l10n@',
            position: 'bottom',
            fields: 'date',
            dateFormat: '@tracker_date_format@',
            constrain: false,
            step: [@tracker_step_uom@, @tracker_step_units@],
            label: {
                rotate: {degrees: 315},
                // Work around bug in Sencha TimeAxis with Month scale showing 31st of last month
                renderer: function(value, label, storeItem, item, i, display, animate, index) { 
                    var valueDate = new Date(value);
                    var valueDay = valueDate.getDate();
                    while (valueDay > 25 && "Ext.Date.MONTH" === '@tracker_step_uom@') {
                        valueDate = new Date(valueDate.getTime() + 24.0*3600.0*1000.0); // add one day
                        valueDay = valueDate.getDate();
                    }
                    return valueDate.getTime(); 
                }
            }
        }],
        series: [@series_json;noquote@],
        listeners: {
            refresh: function(myChart, eOpts) {
                // Redraw the baselines after refreshing the display

                // Update the stepping for the xAxis
                var xAxis = myChart.axes.get('bottom');
                myChart.calcStep(xAxis);

                myChart.clearBaselines();
                myChart.drawBaselines();
            },

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

        /**                                                                                                                                              * Convert a date into an X position, relative to the left of the surface.
         */
        date2x: function(d) {
            var me = this;
            if (me.debug) console.log('PO.milestone.MilestoneTracker.date2x('+d+'): Starting');
            
            var surfaceHeight = me.surface.height;
            var surfaceWidth = me.surface.width;
            var xAxis = me.axes.map["bottom"];
            var yAxis = me.axes.map["left"];

            var xStart = xAxis.x;
            var xEnd = xAxis.x + xAxis.length;
            var fromTime = xAxis.from;
            var toTime = xAxis.to;

            var diffDate = Math.abs(1.0 * toTime - 1.0 * fromTime);
            if (diffDate < 1.0) return null;
            var dDate = d.getTime();
            var perc = (dDate - fromTime) / (toTime - fromTime);
            if (me.debug) console.log('PO.milestone.MilestoneTracker.date2x: Finished');
            return xStart + (xEnd - xStart) * perc;
        },

        /**
         * Convert a date into an X position, relative to the left of the surface.
         */
        calcStep: function(axis, diffDays) {
            var me = this;
            if (me.debug) console.log('PO.milestone.MilestoneTracker.calcStep: Starting');
        
            if (!axis) axis = me.axes.map["bottom"];
            var fromTime = axis.from;
            var toTime = axis.to;
                if (!diffDays) diffDays = (1.0 * toTime - 1.0 * fromTime) / (24.0 * 3600.0 * 1000.0);
            if (me.debug) console.log('PO.milestone.MilestoneTracker.calcStep: diffDays='+diffDays);

            // Default for > 10 years
            var stepUom = Ext.Date.YEAR;
            var stepUnits = 1;
            var dateFormat = "Y-m";

            if (diffDays < 3650) {
                // between 6 months and 10 years
                stepUom = Ext.Date.MONTH;
                stepUnits = Math.round(diffDays / 250.0);
                if (stepUnits < 1) stepUnits = 1;
                dateFormat = "Y-m";
            }

            if (diffDays < 180) {
                // less than 6 months
                stepUom = Ext.Date.DAY;
                stepUnits = Math.round(diffDays / 15.0);
                if (stepUnits < 1) stepUnits = 1;
                dateFormat = "Y-m-d";
            }

            axis.step = [stepUom, stepUnits];
            axis.dateFormat = dateFormat;

            if (me.debug) console.log('PO.milestone.MilestoneTracker.calcStep: Finished: step='+axis.step+', fmt='+axis.dateFormat);
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
                baselineLine.baseline_p = 1;

                var axisText = me.surface.add({
                    type: 'text',
                    text: model.get('baseline_name') +"\n"+model.get('creation_date'),
                    x: dateX + 5,
                    y: labelY,
                    fill: '#FF0000',
                    font: "10px Arial"
                }).show(true);
                axisText.baseline_p = 1;

                labelY = labelY + 30;
                if (labelY > yAxis.y) { labelY = yAxis.y - yAxis.length; }

            });
        },

        /**
         * Remove red vertical bars
         */
        clearBaselines: function() {
            var me = this;
            var surface = me.surface;
            var items = me.surface.items.items;

            // We have to loop, because the array changes when removing
            var repeat = true;
            while (repeat) {
                repeat = false;

                for (var i = 0, ln = items.length; i < ln; i++) {
                    var sprite = items[i];
                    if (!sprite) continue;
                    var baseline_p = sprite.baseline_p;
                    if (baseline_p) {
                        sprite.remove();
                        repeat = true;
                        break;
                    }
                }
            }
        }

    });


    /* ***********************************************************************
     * Help Menu
     *********************************************************************** */
    var helpMenu = Ext.create('PO.view.menu.HelpMenu', {
        id: 'helpMenu',
        debug: false,
        style: {overflow: 'visible'},						// For the Combo popup
        store: Ext.create('Ext.data.Store', { fields: ['text', 'url'], data: [
            {text: 'Milestone Tracker Help', url: 'http://www.project-open.com/en/package-intranet-milestone'}
//            {text: '-'},
//            {text: 'Only Text'},
//            {text: 'Google', url: 'http://www.google.com'}
        ]})
    });


    /* ***********************************************************************
     * Panel around diagram buttons for zoom in/out
     *********************************************************************** */
    var panel = Ext.create('widget.panel', {
        width: @diagram_width@,
        height: @diagram_height@,
        title: '@diagram_title@',
        renderTo: '@diagram_id@',
        layout: 'fit',
        header: false,
        tbar: [
            '->',
            {
                id: 'milestone_zoom_in',
                xtype: 'button',
                icon: '/intranet/images/navbar_default/zoom_in.png',
                toggleGroup: 'milestone_zoom',
                enableToggle: true,
                pressed: true,
                listeners: {
                    toggle: function(button, pressed, eOpts) {
                        // Remove the extreme start and end dates from the store to zoom in
                        if (!pressed) return;
                        console.log('milestone-tracker.zoom_in:');
                        var idx = milestoneStore.find('id', 'start'); milestoneStore.removeAt(idx);
                        var idx = milestoneStore.find('id', 'end'); milestoneStore.removeAt(idx);
                        chart.calcStep();

                    },
                    render: function(button) {	// button.tooltip doesn't work, so work around here...
                        Ext.create('Ext.tip.ToolTip', {target: button.getEl(), html: 'Show actual data points'});
                    }
                }
            },
            {
                id: 'milestone_zoom_out',
                xtype: 'button',
                icon: '/intranet/images/navbar_default/zoom_out.png',
                enableToggle: true,
                pressed: false,
                toggleGroup: 'milestone_zoom',
                listeners: {
                    toggle: function(button, pressed, eOpts) {
                        // Include the min and max dates as part of the store
                        if (!pressed) return;
                        console.log('milestone-tracker.zoom_out:');
                        
                        var xAxis = chart.axes.map["bottom"];
                        var yAxis = chart.axes.map["left"];

                        var idx = milestoneStore.find('id', 'start'); milestoneStore.removeAt(idx);
                        var idx = milestoneStore.find('id', 'end'); milestoneStore.removeAt(idx);
                        milestoneStore.add(
                            {id: 'start', date: @yrange_start_date_js;noquote@, horizon: @yrange_start_date_js;noquote@},
                            {id: 'end', date: new Date('@project_end_date@'), horizon: new Date('@project_end_date@')}
                        );
			
			// Calculate the new stepping for the X axis before the redraw
                        var diffDays = (new Date('@yrange_end_date@').getTime() - new Date('@yrange_start_date@').getTime()) / (24.0 * 3600.0 * 1000.0);
                        chart.calcStep(xAxis, diffDays);
			// After this line there will a redraw happen
                    },
                    render: function(button) {        // button.tooltip doesn't work, so work around here...
                        Ext.create('Ext.tip.ToolTip', {target: button.getEl(), html: '<nobr>Show entire project</nobr>'});
                    }
                }
            },
            '->',
            { text: 'Help', icon: gifPath+'help.png', menu: helpMenu}
        ],

        items: chart
    });

    chart.calcStep();
    chart.drawBaselines();

});
</script>


<if "1" eq @show_debug_p@>
@debug_html;noquote@
</if>
</if>

