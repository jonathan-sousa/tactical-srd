## Cohérence de l'histoire et de ses dialogues.
extends GdUnitTestSuite

var _registry: DataRegistry
var _story: StoryDef


func before() -> void:
	_registry = DataRegistry.load_from()
	_story = _registry.story


func test_v1_sequence_is_intro_combat_victory() -> void:
	var ids: Array[StringName] = []
	var step := _story.get_step(_story.first_step)
	while step != null:
		ids.append(step.id)
		step = _story.get_step(step.next_step)
	assert_array(ids).contains_exactly(&"intro", &"goblin_ambush", &"victory")


func test_step_ids_are_unique() -> void:
	var ids: Array[StringName] = []
	for step in _story.steps:
		assert_bool(ids.has(step.id)).override_failure_message("Id d'étape en double : %s" % step.id).is_false()
		ids.append(step.id)


func test_every_link_points_to_an_existing_step() -> void:
	assert_object(_story.get_step(_story.first_step)).is_not_null()
	for step in _story.steps:
		for target: StringName in [step.next_step, step.defeat_step]:
			if not target.is_empty():
				assert_object(_story.get_step(target)) \
					.override_failure_message("%s pointe vers une étape inconnue : %s" % [step.id, target]) \
					.is_not_null()


func test_every_step_is_reachable_and_there_is_exactly_one_end() -> void:
	var reached: Array[StringName] = []
	var to_visit: Array[StringName] = [_story.first_step]
	while not to_visit.is_empty():
		var id: StringName = to_visit.pop_back()
		if reached.has(id):
			continue
		reached.append(id)
		var step := _story.get_step(id)
		for target: StringName in [step.next_step, step.defeat_step]:
			if not target.is_empty():
				to_visit.append(target)

	var ends := 0
	for step in _story.steps:
		assert_bool(reached.has(step.id)).override_failure_message("Étape inaccessible : %s" % step.id).is_true()
		if step.is_end():
			ends += 1
	assert_int(ends).is_equal(1)


func test_each_step_has_the_content_of_its_kind() -> void:
	for step in _story.steps:
		match step.kind:
			StoryStep.Kind.DIALOGUE:
				assert_object(step.dialogue).override_failure_message("%s : dialogue manquant" % step.id).is_not_null()
			StoryStep.Kind.ENCOUNTER:
				assert_object(step.encounter).override_failure_message("%s : rencontre manquante" % step.id).is_not_null()


func test_steps_use_registry_files() -> void:
	assert_object(_story.get_step(&"goblin_ambush").encounter).is_same(_registry.encounter(&"goblin_ambush"))
	assert_object(_story.get_step(&"intro").dialogue).is_same(_registry.dialogue(&"intro"))


func test_intro_has_3_to_6_lines() -> void:
	assert_int(_registry.dialogue(&"intro").lines.size()).is_between(3, 6)


func test_no_dialogue_line_is_empty() -> void:
	for dialogue_id: StringName in [&"intro", &"victory"]:
		for line in _registry.dialogue(dialogue_id).lines:
			assert_str(line.speaker.strip_edges()).is_not_empty()
			assert_str(line.text.strip_edges()).is_not_empty()
