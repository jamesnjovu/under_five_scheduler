const GrowthChartHook = {
    mounted() {
        this.initChart();

        // Handle updates from LiveView
        this.handleEvent("update_growth_chart", (data) => {
            this.updateChart(data);
        });
    },

    initChart() {
        const chartData = JSON.parse(this.el.dataset.growth || '{}');
        const childAge = this.el.dataset.age || '0';

        // Weight chart
        if (chartData.weights && chartData.weights.length > 0) {
            const weightOptions = {
                chart: {
                    type: 'line',
                    height: 350,
                    toolbar: {
                        show: false
                    },
                    animations: {
                        enabled: true
                    }
                },
                series: [{
                    name: 'Weight (kg)',
                    data: chartData.weights
                }],
                xaxis: {
                    categories: chartData.dates || [],
                    title: {
                        text: 'Date'
                    }
                },
                yaxis: {
                    title: {
                        text: 'Weight (kg)'
                    }
                },
                title: {
                    text: 'Weight Growth Chart',
                    align: 'center'
                },
                colors: ['#3B82F6'], // Blue color
                markers: {
                    size: 5
                },
                stroke: {
                    curve: 'smooth',
                    width: 3
                },
                tooltip: {
                    y: {
                        formatter: (value) => `${value} kg`
                    }
                }
            };

            this.weightChart = new ApexCharts(
                document.querySelector("#weight-chart"),
                weightOptions
            );
            this.weightChart.render();
        }

        // Height chart
        if (chartData.heights && chartData.heights.length > 0) {
            const heightOptions = {
                chart: {
                    type: 'line',
                    height: 350,
                    toolbar: {
                        show: false
                    },
                    animations: {
                        enabled: true
                    }
                },
                series: [{
                    name: 'Height (cm)',
                    data: chartData.heights
                }],
                xaxis: {
                    categories: chartData.dates || [],
                    title: {
                        text: 'Date'
                    }
                },
                yaxis: {
                    title: {
                        text: 'Height (cm)'
                    }
                },
                title: {
                    text: 'Height Growth Chart',
                    align: 'center'
                },
                colors: ['#10B981'], // Green color
                markers: {
                    size: 5
                },
                stroke: {
                    curve: 'smooth',
                    width: 3
                },
                tooltip: {
                    y: {
                        formatter: (value) => `${value} cm`
                    }
                }
            };

            this.heightChart = new ApexCharts(
                document.querySelector("#height-chart"),
                heightOptions
            );
            this.heightChart.render();
        }

        // Head circumference chart (only for children < 3 years old)
        if (parseFloat(childAge) < 3 && chartData.head_circumferences && chartData.head_circumferences.length > 0) {
            const headOptions = {
                chart: {
                    type: 'line',
                    height: 350,
                    toolbar: {
                        show: false
                    },
                    animations: {
                        enabled: true
                    }
                },
                series: [{
                    name: 'Head Circ. (cm)',
                    data: chartData.head_circumferences
                }],
                xaxis: {
                    categories: chartData.dates || [],
                    title: {
                        text: 'Date'
                    }
                },
                yaxis: {
                    title: {
                        text: 'Head Circ. (cm)'
                    }
                },
                title: {
                    text: 'Head Circumference Growth Chart',
                    align: 'center'
                },
                colors: ['#F59E0B'], // Amber color
                markers: {
                    size: 5
                },
                stroke: {
                    curve: 'smooth',
                    width: 3
                },
                tooltip: {
                    y: {
                        formatter: (value) => `${value} cm`
                    }
                }
            };

            this.headChart = new ApexCharts(
                document.querySelector("#head-chart"),
                headOptions
            );
            this.headChart.render();
        }
    },

    updateChart(data) {
        if (this.weightChart && data.weights) {
            this.weightChart.updateSeries([{
                name: 'Weight (kg)',
                data: data.weights
            }]);

            this.weightChart.updateOptions({
                xaxis: {
                    categories: data.dates
                }
            });
        }

        if (this.heightChart && data.heights) {
            this.heightChart.updateSeries([{
                name: 'Height (cm)',
                data: data.heights
            }]);

            this.heightChart.updateOptions({
                xaxis: {
                    categories: data.dates
                }
            });
        }

        if (this.headChart && data.head_circumferences) {
            this.headChart.updateSeries([{
                name: 'Head Circ. (cm)',
                data: data.head_circumferences
            }]);

            this.headChart.updateOptions({
                xaxis: {
                    categories: data.dates
                }
            });
        }
    }
};

// Add this to your hooks.js file and make sure it's imported in app.js
export default {
    GrowthChartHook
};
