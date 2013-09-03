(function() {

	Renderer = function(canvas) {
		var dom = $(canvas)
		var canvas = dom.get(0)
		var ctx = canvas.getContext("2d")
		var gfx = arbor.Graphics(canvas)
		var particleSystem = null
		var removedDirections = false;

		var selected = null, nearest = null, _mouseP = null;

		var nodeFn = function(node, pt) {
			// node: {mass:#, p:{x,y}, name:"", data:{}}
			// pt:   {x:#, y:#}  node position in screen coords

			// Hide hidden nodes
			if (node.data.alpha === 0)
				return

			// Load extra info
			var imageob = node.data.imageob;
			var radius = parseInt(node.data.radius);
			// determine the box size and round off the coords if we'll be
			// drawing a text label (awful alignment jitter otherwise...)
			var label = node.data.label || "";
			var w = ctx.measureText("" + label).width + 20;
			if (w < radius) {
				w = radius;
			} else {
				node.data.radius = w;
			}
			if (!("" + label).match(/^[ \t]*$/)) {
				pt.x = Math.floor(pt.x)
				pt.y = Math.floor(pt.y)
			} else {
				label = null
			}

			// Set colour
			if (node.data.color)
				ctx.fillStyle = node.data.color
			else
				ctx.fillStyle = "rgba(0,0,0,.2)"
			if (node.data.color == 'none')
				ctx.fillStyle = "white"

			// Draw the object
			if (node.data.shape == 'dot') {

				// red or green border

				if (!node.data.followerExpanded || !node.data.followingExpanded) {
					gfx.oval(pt.x - w / 2, pt.y - w / 2, w, w, {
						fill : 'green',
						alpha : 1
					});
				} else {
					gfx.oval(pt.x - w / 2, pt.y - w / 2, w, w, {
						fill : 'red',
						alpha : 1
					});
				}

				gfx.oval(pt.x - w / 2 + 2, pt.y - w / 2 + 2, w - 4, w - 4, {
					fill : ctx.fillStyle,
					alpha : node.data.alpha
				});
				nodeBoxes[node.name] = [pt.x - w / 2, pt.y - w / 2, w, w]
				// Does it have an image?
				if (imageob) {
					// Images are cached
					var img_x = Math.max(0, pt.x - 13);
					var img_y = Math.max(0, pt.y - 25);
					ctx.drawImage(imageob, img_x, img_y, 26, 26)
				}
			} else {
				// If none of the above, draw a rectangle
				gfx.rect(pt.x - w / 2, pt.y - 10, w, 20, 4, {
					fill : ctx.fillStyle,
					alpha : node.data.alpha
				})
				nodeBoxes[node.name] = [pt.x - w / 2, pt.y - 11, w, 22]
			}

			// Draw the text
			if (label) {
				ctx.font = "12px Helvetica";
				ctx.textAlign = "center";
				ctx.lineWidth = 1;
				ctx.fillStyle = "white";
				ctx.strokeStyle = 'black';
				var y_offset = node.data.shape == 'dot' ? 12 : 4;
				ctx.fillText(label || "", pt.x, pt.y + y_offset);
			}

			if (node.data.followingLoading || node.data.followerLoading) {
				gfx.oval(pt.x - w / 2, pt.y - w / 2, w, w, {
					fill : 'white',
					alpha : 0.7
				});
				ctx.font = "16px Helvetica";
				ctx.fillStyle = "black";
				ctx.fillText("loading...", pt.x, pt.y + 3);
			}

		}, edgeFn = function(edge, pt1, pt2) {
			// edge: {source:Node, target:Node, length:#, data:{}}
			// pt1:  {x:#, y:#}  source position in screen coords
			// pt2:  {x:#, y:#}  target position in screen coords

			// Don't draw lines that shouldn't be there
			if (edge.source.data.alpha * edge.target.data.alpha == 0)
				return;
			// gfx.line(pt1, pt2, {
			// stroke : colour.black,
			// width : 2,
			// alpha : edge.target.data.alpha
			// });

			// edge: {source:Node, target:Node, length:#, data:{}}
			// pt1:  {x:#, y:#}  source position in screen coords
			// pt2:  {x:#, y:#}  target position in screen coords

			var weight = 0;
			var color = colour.black;

			// trace(color)
			if (!color || ("" + color).match(/^[ \t]*$/))
				color = null

			// find the start point
			if (edge.source.data.shape == 'dot')
				var tail = intersect_line_dot(pt2, pt1, edge.source.data.radius);
			else
				var tail = intersect_line_box(pt2, pt1, nodeBoxes[edge.source.name]);
			var head = intersect_line_dot(pt1, pt2, edge.target.data.radius);

			ctx.save()
			ctx.beginPath()

			if (!isNaN(weight))
				ctx.lineWidth = weight
			if (color)
				ctx.strokeStyle = color
			// if (color) trace(color)
			ctx.fillStyle = null

			ctx.moveTo(tail.x, tail.y)
			ctx.lineTo(head.x, head.y)
			ctx.stroke()
			ctx.restore()

			ctx.save()
			// move to the head position of the edge we just drew
			var wt = !isNaN(weight) ? parseFloat(weight) : ctx.lineWidth
			var arrowLength = 6 + wt
			var arrowWidth = 2 + wt
			ctx.fillStyle = (color) ? color : ctx.strokeStyle
			ctx.translate(head.x, head.y);
			ctx.rotate(Math.atan2(head.y - tail.y, head.x - tail.x));

			// delete some of the edge that's already there (so the point isn't hidden)
			ctx.clearRect(-arrowLength / 2, -wt / 2, arrowLength / 2, wt)

			// draw the chevron
			ctx.beginPath();
			ctx.moveTo(-arrowLength, arrowWidth);
			ctx.lineTo(0, 0);
			ctx.lineTo(-arrowLength, -arrowWidth);
			ctx.lineTo(-arrowLength * 0.8, -0);
			ctx.closePath();
			ctx.fill();
			ctx.restore()

		}, nodeBoxes = {};

		// Main output section
		var that = {
			init : function(system) {
				particleSystem = system;
				particleSystem.screenSize(canvas.width, canvas.height);
				particleSystem.screenPadding(25, 50);

				that.initMouseHandling();

				// Preload all images into the node object
				particleSystem.eachNode(function(node, pt) {
					if (node.data.image) {
						node.data.imageob = new Image();
						node.data.imageob.src = node.data.image;
					}
				});

				// Set nodeBoxes
				particleSystem.eachNode(nodeFn);

				$(window).resize(that.resize);
				that.resize();
			},

			resize : function() {
				canvas.width = $(window).width()
				canvas.height = .8 * $(window).height()
				sys.screen({
					size : {
						width : canvas.width,
						height : canvas.height
					}
				})
				that.redraw()
			},

			redraw : function() {
				gfx.clear();
				// convenience ƒ: clears the whole canvas rect
				// draw the nodes & save their bounds for edge drawing

				// draw the edges
				particleSystem.eachEdge(edgeFn);

				// draw the nodes
				particleSystem.eachNode(nodeFn);
			},
			switchMode : function(e) {
				if (e.mode == 'hidden') {
					dom.stop(true).fadeTo(e.dt, 0, function() {
						if (sys)
							sys.stop()
						$(this).hide()
					})
				} else if (e.mode == 'visible') {
					dom.stop(true).css('opacity', 0).show().fadeTo(e.dt, 1, function() {
						that.resize()
					})
					if (sys)
						sys.start()
				}
			},

			switchSection : function(newSection) {
				var parent = sys.getEdgesFrom(newSection)[0].source;
				var children = $.map(sys.getEdgesFrom(newSection), function(edge) {
					return edge.target;
				})

				sys.eachNode(function(node) {
					if (node.data.shape == 'dot')
						return;
					// skip all but leafnodes
					var nowVisible = ($.inArray(node, children) >= 0);
					var newAlpha = (nowVisible) ? 1 : 0;
					var dt = (nowVisible) ? .5 : .5;
					sys.tweenNode(node, dt, {
						alpha : newAlpha
					})
					if (newAlpha == 1) {
						node.p.x = parent.p.x + 3 * Math.random() - .025;
						node.p.y = parent.p.y + 3 * Math.random() - .025;
						node.tempMass = .001;
					}
				})
			},

			initMouseHandling : function() {
				// no-nonsense drag and drop (thanks springy.js)
				selected = null;
				nearest = null;
				var dragged = null;
				var oldmass = 1

				var _section = null

				var handler = {
					moved : function(e) {
						var pos = $(canvas).offset();
						_mouseP = arbor.Point(e.pageX - pos.left, e.pageY - pos.top)
						nearest = sys.nearest(_mouseP);

						if (!nearest.node)
							return false

						if (nearest.node.data.shape != 'dot') {
							selected = (nearest.distance < 50) ? nearest : null

							if (selected) {
								dom.addClass('linkable')
								// Will need to re-enable this for clickable links
								// window.status = selected.node.data.link.replace(/^\//,"http://"+window.location.host+"/").replace(/^#/,'')
							} else {
								dom.removeClass('linkable')
								window.status = ''
							}
						}

						return false
					},
					clicked : function(e) {
						var pos = $(canvas).offset();
						_mouseP = arbor.Point(e.pageX - pos.left, e.pageY - pos.top)
						nearest = dragged = sys.nearest(_mouseP);

						if (nearest && nearest.node && jQuery.isNumeric(nearest.node.name)) {
							var clickedNode = nearest.node
							// Remove directions
							if (!removedDirections) {
								if (sys.getNode('click'))
									sys.pruneNode('click');
								if (sys.getNode('user'))
									sys.pruneNode('user');
								if (sys.getNode('border'))
									sys.pruneNode('border');
								removedDirections = true;
							}

							// Get Followings
							if (!clickedNode.data.followingExpanded && !clickedNode.data.followingLoading) {
								clickedNode.data.followingLoading = true;

								if (clickedNode.data.followingPage == null)
									clickedNode.data.followingPage = 0;

								$.ajax({
									url : "graph/friends",
									data : {
										id : clickedNode.name,
										page : clickedNode.data.followingPage
									},
								}).success(function(data) {

									$.each(data, function(index, value) {

										var node = sys.getNode(value.id);

										if (!node) {
											node = sys.addNode(value.id, {
												label : '@' + value.screen_name,
												color : colour.orange,
												shape : 'dot',
												radius : 70,
												alpha : 1,
												image : value.profile_image_url_https,
											});

											if (node.data.image) {
												node.data.imageob = new Image();
												node.data.imageob.src = node.data.image;
											}
										}

										sys.addEdge(clickedNode, node);
									});

									if (data.length < 10) {
										clickedNode.data.followingExpanded = true;
									} else {
										clickedNode.data.followingPage++;
									}

								}).error(function() {
									$msg = $.parseHTML("<div style=''>Cannot get friends of " + clickedNode.data.label + " at this moment</div>");
									$('#error').prepend($msg);
									$($msg).delay(5000).fadeOut(800, function() {
										$(this).remove();
									});
								}).complete(function() {
									clickedNode.data.followingLoading = false;
								});
							}

							// Get Followers
							if (!clickedNode.data.followerExpanded && !clickedNode.data.followerLoading) {
								clickedNode.data.followerLoading = true;

								if (clickedNode.data.followerPage == null)
									clickedNode.data.followerPage = 0;

								$.ajax({
									url : "graph/followers",
									data : {
										id : clickedNode.name,
										page : clickedNode.data.followerPage
									},
								}).success(function(data) {

									$.each(data, function(index, value) {

										var node = sys.getNode(value.id);

										if (!node) {
											node = sys.addNode(value.id, {
												label : '@' + value.screen_name,
												color : colour.orange,
												shape : 'dot',
												radius : 70,
												alpha : 1,
												image : value.profile_image_url_https,
											});

											if (node.data.image) {
												node.data.imageob = new Image();
												node.data.imageob.src = node.data.image;
											}
										}

										sys.addEdge(node, clickedNode);
									});

									if (data.length < 10) {
										clickedNode.data.followerExpanded = true;
									} else {
										clickedNode.data.followerPage++;
									}

								}).error(function() {
									$msg = $.parseHTML("<div style=''>Cannot get followers of " + clickedNode.data.label + " at this moment</div>");
									$('#error').prepend($msg);
									$($msg).delay(5000).fadeOut(800, function() {
										$(this).remove();
									});
								}).complete(function() {
									clickedNode.data.followerLoading = false;
								});
							}
						}

						if (dragged && dragged.node !== null)
							dragged.node.fixed = true

						$(canvas).unbind('mousemove', handler.moved);
						$(canvas).bind('mousemove', handler.dragged)
						$(window).bind('mouseup', handler.dropped)

						return false
					},
					dragged : function(e) {
						var old_nearest = nearest && nearest.node._id
						var pos = $(canvas).offset();
						var s = arbor.Point(e.pageX - pos.left, e.pageY - pos.top)

						if (!nearest)
							return
						if (dragged !== null && dragged.node !== null) {
							var p = sys.fromScreen(s)
							dragged.node.p = p
						}

						return false
					},

					dropped : function(e) {
						if (dragged === null || dragged.node === undefined)
							return
						if (dragged.node !== null)
							dragged.node.fixed = false
						dragged.node.tempMass = 1000
						dragged = null;
						// selected = null
						$(canvas).unbind('mousemove', handler.dragged)
						$(window).unbind('mouseup', handler.dropped)
						$(canvas).bind('mousemove', handler.moved);
						_mouseP = null
						return false
					}
				}

				$(canvas).mousedown(handler.clicked);
				$(canvas).mousemove(handler.moved);

			}
		}

		// helpers for figuring out where to draw arrows (thanks springy.js)
		var intersect_line_line = function(p1, p2, p3, p4) {
			var denom = ((p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y));
			if (denom === 0)
				return false
			// lines are parallel
			var ua = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / denom;
			var ub = ((p2.x - p1.x) * (p1.y - p3.y) - (p2.y - p1.y) * (p1.x - p3.x)) / denom;

			if (ua < 0 || ua > 1 || ub < 0 || ub > 1)
				return false
			return arbor.Point(p1.x + ua * (p2.x - p1.x), p1.y + ua * (p2.y - p1.y));
		}
		var intersect_line_box = function(p1, p2, boxTuple) {
			var p3 = {
				x : boxTuple[0],
				y : boxTuple[1]
			}, w = boxTuple[2], h = boxTuple[3]

			var tl = {
				x : p3.x,
				y : p3.y
			};
			var tr = {
				x : p3.x + w,
				y : p3.y
			};
			var bl = {
				x : p3.x,
				y : p3.y + h
			};
			var br = {
				x : p3.x + w,
				y : p3.y + h
			};

			return intersect_line_line(p1, p2, tl, tr) || intersect_line_line(p1, p2, tr, br) || intersect_line_line(p1, p2, br, bl) || intersect_line_line(p1, p2, bl, tl) || false
		}
		var intersect_line_dot = function(p1, p2, r) {
			var dx = p2.x - p1.x;
			var dy = p2.y - p1.y;
			var len = Math.sqrt(Math.pow(dx, 2) + Math.pow(dy, 2));

			var ix = r * dx / len;
			var iy = r * dy / len;

			return arbor.Point(p2.x - ix / 2, p2.y - iy / 2);
		}

		return that
	}
})()
