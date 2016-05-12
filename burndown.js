function burndown(release) {
    $.getJSON('releases.json', function(releases) {
        if (release in releases) {
            start = Date.parse(releases[release]['start']);
            rcs = Date.parse(releases[release]['rcs']);
            target = Date.parse(releases[release]['target']);
    
            $.getJSON('burndown-'+release+'.json', function(mydata) {
                $.each(mydata.closed, function(i, v) {
                    v[0] = Date.parse(v[0]);
                });
                $('#burndown-container').highcharts({
                    title: {
                        text: 'Progress toward '+release+' release'
                    },
                    xAxis: {
                        type: 'datetime',
                        title: {
                            text: 'Date'
                        },
                        plotLines: [
                            {
                                color: '#ef2929',
                                value: target,
                                width: '1',
                                label: {
                                    text: 'Target',
                                    style: {
                                        color: '#a40000'
                                    }
                                },
                            },
                            {
                                color: '#75507b',
                                value: Date.now(),
                                width: '1',
                                label: {
                                    text: 'Now',
                                    style: {
                                        color: '#5c3566'
                                    }
                                },
                            },
                        ],
                        plotBands: [
                            {
                                color: '#eeeeec',
                                from: rcs,
                                to: target,
                                label: {
                                    text: 'RCs',
                                    style: {
                                        color: '#555753'
                                    }
                                },
                            },
                        ],
                    },
                    yAxis: {
                        title: {
                            text: 'Open Issues & Pull Requests'
                        },
                        min: 0
                    },
                    tooltip: {
                        pointFormat: '<b>{point.y:.0f}</b> open'
                    },
                    plotOptions: {
                        series: {
                            marker: {
                                enabled: false
                            }
                        },
                    },
                    series: [
                        {
                            name: 'Ideal',
                            data: [
                                [start, mydata.to_burn],
                                [target, 0]
                            ],
                            color: '#73d216',
                            dashStyle: 'shortdash',
                            enableMouseTracking: false,
                        },
                        {
                            name: 'Trend',
                            type: 'line',
                            data: (function() {
                                start = mydata.closed[0][0];
                                fit = fitData(mydata.closed);
                                return [
                                    [start, fit.y(start)],
                                    [fit.x(0), 0],
                                ];
                            })(),
                            color: '#729fcf',
                            dashStyle: 'shortdot',
                            enableMouseTracking: false,
                        },
                        {
                            name: 'Predicted',
                            type: 'line',
                            data: (function() {
                                start = mydata.closed[0][0] / 1000;
                                end = target / 1000;
                                console.log("Start: " + start);
                                console.log("End: " + end);
                                points = [];
                                for (i = start; i<= end; i += 24*60*60*7) {
                                    console.log(i);
                                }
                                return points;
                            })(),
                            color: '#204a87',
                            dashStyle: 'shortdot',
                            enableMouseTracking: false,
                        },
                        {
                            name: 'Actual',
                            data: mydata.closed,
                            step: 'left',
                            color: '#3465a4',
                        },
                    ]
                });
            });
        } else {
            $('#burndown-container').html('<p class="text-muted">Cannot draw burndown, no dates for '+release+'!</p>');
        }
    });
}
