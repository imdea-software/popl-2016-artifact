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
    var counts = {};
    data.forEach(function(datum) {
      var object = datum.history.split(".")[0]
      if (datum.violation) {        
        if (!(object in counts))
          counts[object] = {}
        if (!(datum.algorithm in counts[object]))
          counts[object][datum.algorithm] = 0;
        counts[object][datum.algorithm] += 1;
      }
    });
    var data = [];
    for (obj in counts) {
      var counts_for_obj = []
      for (alg in counts[obj]) {
        counts_for_obj.push({object: obj, algorithm: alg, count: counts[obj][alg]})
      }
      data.push({object: obj, counts: counts_for_obj})
    }
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

    x.domain(data.map(function(d) { return d.object; }));
    y.domain([1,d3.max(data, function(d) { return d3.max(d.counts, function(d) { return d.count; }); })]);

    var xx = d3.scale.ordinal()
        .rangeRoundBands([0, x.rangeBand()], .1)
        .domain(data[0].counts.map(function(d) { return d.algorithm; }));

    svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis)

    svg.append("g")
        .attr("class", "y axis")
        .call(yAxis)
      .append("text")
        .attr("transform", "rotate(-90)")
        .attr("y", 6)
        .attr("dy", ".71em")
        .style("text-anchor", "end")
        .text("Violations discovered");

    var bar_groups = svg.selectAll(".object")
        .data(data);
        
    var bars = bar_groups.enter().append("g")
        .attr("class", "object")
        .selectAll(".bar")
        .data(function(d) { return d.counts; });

    bars.enter().append("rect")
        .attr("class", "bar")
        .attr("x", function(d) { return x(d.object) + xx(d.algorithm); })
        .attr("y", function(d) { return y(d.count); })
        .attr("height", function(d) { return height - y(d.count); })
        .attr("width", xx.rangeBand());

    bars.enter().append("text")
        .attr("transform", function(d) { return "translate(" + (x(d.object) + xx(d.algorithm) + xx.rangeBand()/2 + 2) + "," + (height-10) + ") rotate(-90)"})
        .text(function(d) { return d.algorithm; })

  });
}
