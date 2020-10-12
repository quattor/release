function burndown(release) {
    $.getJSON('releases.json', function(releases) {
        if (release in releases) {
            start = Date.parse(releases[release]['start']);
            rcs = Date.parse(releases[release]['rcs']);
            target = Date.parse(releases[release]['target']);
    
            $.getJSON('burndown-'+release+'.json', function(mydata) {
                if (mydata.closed && mydata.closed.length > 0) {
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
                                    color: '#eeeeec7f',
                                    from: rcs,
                                    to: target,
                                    label: {
                                        text: 'Freeze & RCs',
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
                                name: 'Ideal World',
                                data: [
                                    [start, mydata.to_burn],
                                    [target, 0]
                                ],
                                color: '#73d216',
                                dashStyle: 'shortdash',
                                enableMouseTracking: false,
                            },
                            {
                                name: 'Linear Regression',
                                type: 'line',
                                data: (function() {
                                    start_lin = mydata.closed[0][0];
                                    tdata = mydata.closed;
                                    tdata.push([Date.now(), tdata.slice(-1)[0][1]]);
                                    fit = fitData(tdata);
                                    return [
                                        [start_lin, fit.y(start_lin)],
                                        [target, fit.y(target)],
                                    ];
                                })(),
                                color: '#ad7fa8',
                                dashStyle: 'shortdot',
                                //visible: false,
                                enableMouseTracking: false,
                            },
                            /*{
                                name: 'Prediction',
                                type: 'line',
                                data: (function() {
                                    secondsinday = 24 * 60 * 60;
                                    start_secs = start / 1000;
                                    // Account for overshoot
                                    end_secs = (target + target - Date.now()) / 1000;
                                    days = (end_secs - start_secs) / secondsinday;
                                    // Roughly the number of working days in a month
                                    coeff_a = mydata.to_burn / (secondsinday * (days / 20));
                                    // Number of working days in a week
                                    coeff_b = mydata.to_burn / (secondsinday / (days / 5))
                                    points = [];
                                    for (day = 0; day <= days; day++) {
                                        y = -coeff_a * Math.pow(day, 3) + coeff_b * Math.pow(day, 2) - day + mydata.to_burn;
                                        x = start + day * secondsinday * 1000;
                                        if (y < 0) break;
                                        points.push([x, y]);
                                    }
                                    return points;
                                })(),
                                color: '#75507b',
                                dashStyle: 'shortdash',
                                enableMouseTracking: false,
                            },*/
                            {
                                name: 'Reality',
                                data: mydata.closed,
                                step: 'left',
                                color: '#3465a4',
                            },
                        ]
                    });
                } else {
                    $('#burndown-container').html('<p class="text-muted">No burndown data for '+release+' yet.</p>');
                }
            });
        } else {
            $('#burndown-container').html('<p class="text-muted">Cannot draw burndown, no dates for '+release+'!</p>');
        }
    });
}
