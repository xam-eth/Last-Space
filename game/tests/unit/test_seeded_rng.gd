extends RefCounted
## TestSeededRng — determinism RNG (QA_PLAN.md: simulasi harus bisa direplay).


func run(t) -> void:
	SeededRng.set_seed(42)
	var a1 := SeededRng.next_int()
	var a2 := SeededRng.next_int()
	SeededRng.set_seed(42)
	var b1 := SeededRng.next_int()
	var b2 := SeededRng.next_int()
	t.check_eq("rng.deterministic_sequence", [a1, a2], [b1, b2])

	SeededRng.set_seed(1)
	var seq1 := []
	for i in 10:
		seq1.append(SeededRng.next_int())
	SeededRng.set_seed(2)
	var seq2 := []
	for i in 10:
		seq2.append(SeededRng.next_int())
	t.check("rng.different_seeds_differ", seq1 != seq2)

	SeededRng.set_seed(7)
	var ok := true
	for i in 200:
		var v := SeededRng.next_int_range(5, 9)
		if v < 5 or v > 9:
			ok = false
	t.check("rng.range_bounds_inclusive", ok)

	SeededRng.set_seed(99)
	var f := SeededRng.next_float()
	t.check("rng.float_in_unit_range", f >= 0.0 and f <= 1.0, "f=%s" % f)
