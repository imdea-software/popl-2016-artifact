violations_covered_plot = function(datafile, width, height, margin) {

  var x = d3.scale.ordinal()
      .rangeRoundBands([0, width], .1);

  var y = d3.scale.linear()
      .range([height, 0]);

  var xAxis = d3.svg.axis()
      .scale(x)
      .orient("bottom")

  var yAxis = d3.svg.axis()
      .scale(y)
      .orient("left");

  var svg = d3.select("body").append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
    .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

  function data_to_violation_counts(data) {
    counts = {};
    data.forEach(function(datum) {
      if (!(datum.algorithm in counts))
        counts[datum.algorithm] = 0;
      counts[datum.algorithm] += 1;
    });
    data = [];
    for (key in counts)
      data.push({algorithm: key, count: counts[key]})
    return data;
  }

  function data_shape(d) {
    a = d.algorithm
    shape =  a.match(/Enumerate/) ? "diamond" :
      a.match(/Symbolic/) ? "square" :
      a.match(/Counting/) ? "circle" :
      a.match(/Saturate/) ? "cross" :
      "triangle-down";
    if (shape == "triangle-down")
      console.log("Unexpected algorithm: " + a);
    return shape;
  }

  function data_size(h) {
    return 50;
  }

  function type(d) {
    d.steps = +d.steps.replace(/\*/g,'')
    d.time = +d.time.replace(/\*|s/g,'')
    d.violation = d.violation == "true"
    return d;
  }

  d3.tsv(datafile, type, function(error, data) {
    data = data_to_violation_counts(data)
    x.domain(data.map(function(d) { return d.algorithm; }));
    y.domain([-1,d3.max(data, function(d) { return d.count; })]);

    svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis)
      .append("text")
        .attr("x", width)
        .attr("y", -6)
        .attr("dy", "-.31em")
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
        .text("Time");

    var bars = svg.selectAll(".bar")
        .data(data);
        
    bars.enter().append("rect")
        .attr("class", "bar")
        .attr("x", function(d) { return x(d.algorithm); })
        .attr("y", function(d) { return y(d.count); })
        .attr("height", function(d) { return height - y(d.count); })
        .attr("width", x.rangeBand());

    bars.enter().append("text")
        .attr("transform", function(d) { return "translate(" + (x(d.algorithm) + x.rangeBand()/2 + 5) + "," + (height-10) + ") rotate(-90)"})
        .text(function(d) { return d.algorithm; })

  });
}
