extends SceneTree

const Sim = preload("res://scripts/lab_sim.gd")
const Levels = preload("res://scripts/lab_levels.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func advance(s, count: int) -> void:
	for i in count:
		s.step()
		check(absf(s.total_water() + s.drained - s.initial_water) < 0.0001, "Water must be conserved")
		for n in s.nodes:
			check(n.volume >= -0.0001 and n.volume <= n.capacity + 0.0001, "Volume must stay within capacity")

func fresh(index: int):
	var s = Sim.new()
	s.load_level(Levels.get_levels()[index])
	return s

func _init() -> void:
	var s = fresh(0)
	check(s.place_tank("T"), "Install high tank")
	check(not s.place_tank("U"), "Respect tank budget")
	s.start()
	check(not s.place_tank("T"), "Do not move running water containers")
	advance(s, 160)
	check(s.won, "High tank must supply goal")
	var low = fresh(0)
	low.place_tank("U")
	low.start()
	advance(low, 160)
	check(not low.won, "Low tank cannot overcome required water level")
	var unconfigured = fresh(1)
	unconfigured.start()
	advance(unconfigured, 240)
	check(not unconfigured.won, "Default open network is not a free solution")
	for automatic in [false, true]:
		s = fresh(1)
		s.cycle_check("AB")
		s.cycle_check("AB") # B -> A protects A from draining.
		if automatic:
			check(s.link_float("A", "R", 2, 6), "Attach float to any compatible router")
		s.start()
		for i in 180:
			if not automatic and s.node("A").volume >= 6 and s.node("R").route == 0:
				s.actuate("R")
			advance(s, 1)
		check(s.won, "Dual pools solution, automatic=" + str(automatic))
		check((s.operations == 0 and s.automatic_actions > 0) if automatic else s.operations > 0, "Distinct manual/automatic solutions")
		print("Dual pools ", automatic, ": ", s.score_text())
	s = fresh(2)
	s.place_tank("T")
	check(not s.link_float("T", "IN", 6, 2), "Reject inverted thresholds")
	check(s.link_float("T", "IN", 2, 6), "Attach float to inlet valve")
	s.start()
	check(not s.actuate("IN"), "Reject manual conflict with active float")
	advance(s, 200)
	check(s.won, "Feedback irrigation must succeed")
	check(s.automatic_actions >= 2, "Controller must close and reopen autonomously")
	print("Feedback: ", s.score_text())
	var overflow = fresh(2)
	overflow.place_tank("T")
	overflow.start()
	advance(overflow, 100)
	check(overflow.failed and overflow.wasted > 0, "Uncontrolled inlet must overflow; lost water is accounted")
	# Edge storage order cannot change the shared-resource split.
	var normal = fresh(1)
	var reversed = fresh(1)
	normal.place_tank("T")
	reversed.place_tank("T")
	normal.actuate("RT")
	reversed.actuate("RT")
	reversed.edges.reverse()
	normal.start()
	reversed.start()
	for i in 80:
		advance(normal, 1)
		advance(reversed, 1)
		for n in normal.nodes:
			check(absf(n.volume - reversed.node(n.id).volume) < 0.0001, "Edge order independence")
	# Hysteresis stays latched inside the dead band and resets below the low mark.
	s = fresh(2)
	s.place_tank("T")
	s.link_float("T", "IN", 2, 6)
	s.node("T").volume = 6
	s._controllers()
	check(not s.edge("IN").open, "High threshold closes valve")
	s.node("T").volume = 4
	s._controllers()
	check(not s.edge("IN").open, "Dead band retains controller state")
	s.node("T").volume = 2
	s._controllers()
	check(s.edge("IN").open, "Low threshold reopens valve")
	# A reversed check valve rejects pressure-driven A -> B backflow.
	s = fresh(1)
	for e in s.edges:
		e.open = e.id == "AB"
	s.node("S").volume = 0
	s.node("A").volume = 6
	s.initial_water = 6
	s.cycle_check("AB")
	s.cycle_check("AB")
	s.start()
	advance(s, 4)
	check(s.node("B").volume == 0 and s.node("A").volume == 6, "One-way blocks reverse transfer")
	# Goal hold counter resets after water drops below the required mark.
	s = fresh(1)
	for e in s.edges:
		e.open = false
	s.node("S").volume = 0
	s.node("A").volume = 6
	s.node("B").volume = 6
	s.start()
	s.step()
	check(s.stable_ticks == 1 and not s.won, "Transient target hit is not victory")
	s.node("A").volume = 5
	s.step()
	check(s.stable_ticks == 0, "Goal hold requires consecutive qualifying ticks")
	# Reusing a simulation object must reset state and resource inventories.
	s.load_level(Levels.get_levels()[0])
	check(s.floats.is_empty() and s.tick == 0 and not s.started and s.nodes.size() == 4, "Full reset")
	print("LAB TESTS: ", failures, " failure(s)")
	quit(1 if failures else 0)
