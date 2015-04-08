steps_until_timeout_plot = function(datafile, width, height, margin) {

  var timeouts = [5,25,50,75,100];

  function nearestTimeout(t) {
    for (var i=0; i<timeouts.length-1; ++i) {
      if (t < timeouts[i+1])
        return timeouts[i];
    }
    return 100;
  }

  var x = d3.scale.log()
      .range([0, width]);

  var y = d3.scale.linear()
      .range([height, 0]);

  var xAxis = d3.svg.axis()
      .scale(x)
      .orient("bottom")
      .ticks(0,"g");

  var yAxis = d3.svg.axis()
      .scale(y)
      .orient("left")
      .tickValues(timeouts);

  var svg = d3.select("body").append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
    .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

  function data_shape(d) {
    a = d.algorithm
    shape =  a.match(/Enumerate/) ? "diamond" :
      a.match(/Symbolic/) ? "square" :
      a.match(/Bound/) ? "circle" :
      a.match(/Saturate/) ? "cross" :
      "triangle-down";
    if (shape == "triangle-down")
      console.log("Unexpected algorithm: " + a);
    return shape;
  }

  function data_size(h) {
    return 150;
  }

  function type(d) {
    d.steps = +d.steps.replace(/\*/g,'')
    d.time = +d.time.replace(/\*|s/g,'')
    d.violation = d.violation == "true"
    return d;
  }

  var line = d3.svg.line()
      .x(function(d) { return x(d.values); })
      .y(function(d) { return y(d.key); })
      .interpolate("linear");

  d3.tsv(datafile, type, function(error, data) {
    data = data.filter(function(d) { return d.algorithm != "?" && !d.algorithm.match(/Bound/) })

    var averages = d3.nest()
        .key(function(d) { return d.algorithm; })
        .key(function(d) { return d.removal; })
        .key(function(d) { return nearestTimeout(d.time); })
        .rollup(function(d) {
          var step_counts = d.map(function(g) { return +g.steps; }).sort(function(a,b) { return a-b; });
          return {
            counts: step_counts,
            min: d3.min(step_counts),
            max: d3.max(step_counts),
            mean: d3.mean(step_counts),
            q1: d3.quantile(step_counts, 0.25),
            q2: d3.quantile(step_counts, 0.50),
            q3: d3.quantile(step_counts, 0.75),
            median: d3.median(step_counts),
            deviation: d3.deviation(step_counts),
          }})
        .entries(data)
        .map(function(d) {
          return d.values.map(function(e) {
            return e.values.map(function(f) {
              return {
                algorithm: d.key,
                removal: e.key == "true",
                timeout: f.key,
                stats: f.values
              };
            });
          });
        }).reduce(function(d,e) { return d.concat(e); }).reduce(function(d,e) { return d.concat(e); });

    x.domain([10,d3.max(data, function(d) { return d.steps })]);
    y.domain([-0.3,d3.max(data, function(d) { return (d.time / Math.pow(d["weight.mean"],0)) })]);

    timeouts.forEach(function(t) {
      svg.append("line")
        .attr("class", "gridline")
        .attr("x1", x(10))
        .attr("x2", x(10000))
        .attr("y1", y(t))
        .attr("y2", y(t));
    });

    var datapoints = svg.selectAll(".datapoint")
        .data(averages)
      .enter().append("g")
        .attr("class", "datapoint")
        .attr("transform", function(d,i) { return "translate(" + x(d.stats.q2) + "," + (y(d.timeout) - (Math.floor(i/5)%2)*10) + ")"; })

    datapoints.append("line")
      .attr("x1", function(d) { return x(d.stats.min) - x(d.stats.q2); })
      .attr("x2", function(d) { return x(d.stats.max) - x(d.stats.q2); })
      .attr("y1", function(d) { return 0; })
      .attr("y2", function(d) { return 0; });

    datapoints.append("rect")
      .attr("class", function(d) { return d.algorithm.toLowerCase(); })
      .classed("removal", function(d) { return d.removal; })
      .attr("x", function(d) { return x(d.stats.q1) - x(d.stats.q2); })
      .attr("y", -5)
      .attr("width", function(d) { return x(d.stats.q3) - x(d.stats.q1); })
      .attr("height", 10);

    datapoints.append("line")
      .attr("x1", function(d) { return x(d.stats.min) - x(d.stats.q2); })
      .attr("x2", function(d) { return x(d.stats.min) - x(d.stats.q2); })
      .attr("y1", function(d) { return -3; })
      .attr("y2", function(d) { return +3; });

    datapoints.append("line")
      .attr("x1", function(d) { return x(d.stats.q2) - x(d.stats.q2); })
      .attr("x2", function(d) { return x(d.stats.q2) - x(d.stats.q2); })
      .attr("y1", function(d) { return -3; })
      .attr("y2", function(d) { return +3; });

    datapoints.append("line")
      .attr("x1", function(d) { return x(d.stats.max) - x(d.stats.q2); })
      .attr("x2", function(d) { return x(d.stats.max) - x(d.stats.q2); })
      .attr("y1", function(d) { return -3; })
      .attr("y2", function(d) { return +3; });

    datapoints.append("text")
        .attr("dy", "-1em")
        .attr("text-anchor", "middle")
        .text(function(d) { return Math.round(d.stats.q2); });

    datapoints.filter(function(d,i) { return (i % 5) == 4; }).append("text")
        .attr("dy", "-2em")
        .attr("text-anchor", "middle")
        .text(function(d) { return d.algorithm + (d.removal ? "+R" : ""); });

    svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis)
      .append("text")
        .attr("x", width)
        .attr("y", -6)
        // .attr("dy", "-.31em")
        .attr("text-anchor", "end")
        .text("Steps");

    svg.append("g")
        .attr("class", "y axis")
        .call(yAxis)
      .append("text")
        .attr("transform", "rotate(-90)")
        .attr("y", 6)
        .attr("dy", ".71em")
        .style("text-anchor", "end")
        .text("Seconds");

  });

}
