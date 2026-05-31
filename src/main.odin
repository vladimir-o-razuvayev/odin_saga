package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

Build_Result :: struct {
	modules:      [dynamic]Module,
	errors:       [dynamic]Diagnostic,
	source_files: [dynamic]string,
}

Load_Context :: struct {
	result:   ^Build_Result,
	loaded:   ^[dynamic]string,
	base_dir: string,
}

main :: proc() {
	args := os.args
	if len(args) != 3 {
		fmt.eprintln("usage: saga <entry.saga> <output.html>")
		os.exit(2)
	}

	result := build_story(args[1])
	defer free_build_result(result)

	if len(result.errors) > 0 {
		for err in result.errors {
			fmt.eprintf("%s:%d:%d: %s\n", err.pos.file, err.pos.line, err.pos.column, err.message)
		}
		os.exit(1)
	}

	document := html.generate(result.modules[:], "Saga")
	defer delete(document)
	if !os.write_entire_file(args[2], transmute([]byte)document) {
		fmt.eprintf("failed to write %s\n", args[2])
		os.exit(1)
	}

	fmt.printf("wrote %s\n", args[2])
}

build_story :: proc(entry_path: string) -> Build_Result {
	result := Build_Result {
		modules      = make([dynamic]Module),
		errors       = make([dynamic]Diagnostic),
		source_files = make([dynamic]string),
	}
	loaded := make([dynamic]string)
	defer delete(loaded)

	entry_abs, abs_ok := filepath.abs(entry_path, context.temp_allocator)
	if !abs_ok {
		append(
			&result.errors,
			Diagnostic {
				message = fmt.tprintf("failed to resolve %q", entry_path),
				pos = Source_Pos{file = entry_path, line = 1, column = 1},
			},
		)
		return result
	}
	base_dir := filepath.dir(entry_abs)
	defer delete(base_dir)
	load_module(&result, &loaded, base_dir, entry_abs)
	load_all_saga_files(&result, &loaded, base_dir, base_dir)
	if len(result.errors) == 0 {
		validate_targets(&result, base_dir)
	}
	return result
}

load_all_saga_files :: proc(
	result: ^Build_Result,
	loaded: ^[dynamic]string,
	base_dir, dir: string,
) {
	ctx := Load_Context {
		result   = result,
		loaded   = loaded,
		base_dir = base_dir,
	}
	err := filepath.walk(dir, load_saga_walk_proc, &ctx)
	if err != nil {
		append(
			&result.errors,
			Diagnostic {
				message = fmt.tprintf("failed to read directory %q", dir),
				pos = Source_Pos{file = dir, line = 1, column = 1},
			},
		)
	}
}

load_saga_walk_proc :: proc(
	info: os.File_Info,
	in_err: os.Error,
	user_data: rawptr,
) -> (
	err: os.Error,
	skip_dir: bool,
) {
	if in_err != nil {
		return in_err, false
	}
	if info.is_dir || !has_suffix(info.fullpath, ".saga") {
		return nil, false
	}
	ctx := (^Load_Context)(user_data)
	load_module(ctx.result, ctx.loaded, ctx.base_dir, info.fullpath)
	return nil, false
}

load_module :: proc(result: ^Build_Result, loaded: ^[dynamic]string, base_dir, path: string) {
	if has_loaded(loaded[:], path) {
		return
	}
	stable_path := strings.clone(path)
	append(loaded, stable_path)
	append(&result.source_files, stable_path)

	data, ok := os.read_entire_file(stable_path)
	if !ok {
		append(
			&result.errors,
			Diagnostic {
				message = fmt.tprintf("failed to read module %q", stable_path),
				pos = Source_Pos{file = stable_path, line = 1, column = 1},
			},
		)
		return
	}
	defer delete(data)

	lx := lexer.init(string(data), stable_path)
	lexed := lexer.scan_lines(&lx)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	p := parser.init(lexed.lines[:], stable_path)
	parsed := parser.parse(&p)
	for err in lexed.errors {
		append(&parsed.errors, err)
	}

	if len(parsed.errors) > 0 {
		for err in parsed.errors {
			append(&result.errors, err)
		}
		free_parse_result(parsed)
		return
	}

	own_module_strings(&parsed.module)
	append(&result.modules, parsed.module)

}

validate_targets :: proc(result: ^Build_Result, base_dir: string) {
	for module in result.modules {
		for scene in module.scenes {
			if len(scene.widget) > 0 && !is_builtin_widget(scene.widget) {
				append(
					&result.errors,
					Diagnostic {
						message = fmt.tprintf("unknown widget renderer %q", scene.widget),
						pos = scene.pos,
					},
				)
			}

			has_dialogue_speaker := false
			for stmt in scene.statements {
				if stmt.kind == .Image {
					validate_image(result, base_dir, stmt)
					has_dialogue_speaker = false
					continue
				}
				if stmt.kind == .Dialogue {
					validate_dialogue(
						result,
						base_dir,
						module.file,
						scene.path,
						stmt,
						&has_dialogue_speaker,
					)
					continue
				}
				has_dialogue_speaker = false
				if stmt.kind != .Choice {
					continue
				}

				target := stmt.transfer.target
				if len(target.scene_ref) == 0 || target.scene_ref == "end:" {
					continue
				}

				target_module_path := module.file
				if len(target.module_path) > 0 {
					target_module_path = fmt.tprintf("%s%s", base_dir, target.module_path)
				}

				target_module := find_module(result.modules[:], target_module_path)
				if target_module == nil {
					append(
						&result.errors,
						Diagnostic {
							message = fmt.tprintf(
								"unresolved target module %q",
								target.module_path,
							),
							pos = target.pos,
						},
					)
					continue
				}

				target_scene_path := resolve_target_scene_path(scene.path, target.scene_ref)
				target_scene := find_scene(target_module.scenes[:], target_scene_path)
				if target_scene == nil {
					append(
						&result.errors,
						Diagnostic {
							message = fmt.tprintf(
								"unresolved target %q; resolved to %q in %s",
								target.scene_ref,
								target_scene_path,
								target_module.file,
							),
							pos = target.pos,
						},
					)
					continue
				}

			}
		}
	}
}

validate_dialogue :: proc(
	result: ^Build_Result,
	base_dir, module_file, scene_path: string,
	stmt: Statement,
	has_dialogue_speaker: ^bool,
) {
	if len(stmt.speaker.scene_ref) == 0 {
		if !has_dialogue_speaker^ {
			append(
				&result.errors,
				Diagnostic{message = "dialogue continuation has no speaker", pos = stmt.pos},
			)
		}
		return
	}

	target_module_path := module_file
	if len(stmt.speaker.module_path) > 0 {
		target_module_path = fmt.tprintf("%s%s", base_dir, stmt.speaker.module_path)
	}
	target_module := find_module(result.modules[:], target_module_path)
	if target_module == nil {
		append(
			&result.errors,
			Diagnostic {
				message = fmt.tprintf(
					"unresolved dialogue speaker module %q",
					stmt.speaker.module_path,
				),
				pos = stmt.pos,
			},
		)
		return
	}
	target_scene_path := resolve_target_scene_path(scene_path, stmt.speaker.scene_ref)
	target_scene := find_scene(target_module.scenes[:], target_scene_path)
	if target_scene == nil {
		append(
			&result.errors,
			Diagnostic {
				message = fmt.tprintf("unresolved dialogue speaker %q", target_scene_path),
				pos = stmt.pos,
			},
		)
		return
	}
	if target_scene.widget != "std:character" {
		append(
			&result.errors,
			Diagnostic {
				message = fmt.tprintf(
					"dialogue speaker %q is not a std:character widget",
					target_scene_path,
				),
				pos = stmt.pos,
			},
		)
		return
	}
	has_dialogue_speaker^ = true
}

validate_image :: proc(result: ^Build_Result, base_dir: string, stmt: Statement) {
	if len(stmt.image_src) == 0 || !lexer.starts_with(stmt.image_src, "/") {
		return
	}
	asset_path := fmt.tprintf("%s%s", base_dir, stmt.image_src)
	if !os.exists(asset_path) {
		append(
			&result.errors,
			Diagnostic {
				message = fmt.tprintf("missing image asset %q", stmt.image_src),
				pos = stmt.pos,
			},
		)
	}
}

find_module :: proc(modules: []Module, path: string) -> ^Module {
	for i := 0; i < len(modules); i += 1 {
		if modules[i].file == path {
			return &modules[i]
		}
	}
	return nil
}

find_scene :: proc(scenes: []Scene, path: string) -> ^Scene {
	for i := 0; i < len(scenes); i += 1 {
		if scenes[i].path == path {
			return &scenes[i]
		}
	}
	return nil
}

has_scene :: proc(scenes: []Scene, path: string) -> bool {
	return find_scene(scenes, path) != nil
}

is_builtin_widget :: proc(widget: string) -> bool {
	return(
		widget == "std:inventory" ||
		widget == "std:contacts" ||
		widget == "std:item" ||
		widget == "std:status" ||
		widget == "std:character" \
	)
}

resolve_target_scene_path :: proc(current_path, ref: string) -> string {
	if ref == "." {
		return current_path
	}
	if ref == ".." {
		return parent_scene_path(current_path)
	}
	if lexer.starts_with(ref, "..") {
		parent := parent_scene_path(current_path)
		sibling := ref[2:]
		if len(parent) == 0 {
			return sibling
		}
		return fmt.tprintf("%s.%s", parent, sibling)
	}
	if lexer.starts_with(ref, ".") {
		return fmt.tprintf("%s.%s", current_path, ref[1:])
	}
	return ref
}

parent_scene_path :: proc(path: string) -> string {
	last_dot := -1
	for i := 0; i < len(path); i += 1 {
		if path[i] == '.' {
			last_dot = i
		}
	}
	if last_dot < 0 {
		return ""
	}
	return path[:last_dot]
}

has_suffix :: proc(s, suffix: string) -> bool {
	if len(suffix) > len(s) {
		return false
	}
	return s[len(s) - len(suffix):] == suffix
}

has_loaded :: proc(loaded: []string, path: string) -> bool {
	for item in loaded {
		if item == path {
			return true
		}
	}
	return false
}

free_loaded_paths :: proc(loaded: [dynamic]string) {
	for path in loaded {
		delete(path)
	}
	delete(loaded)
}

clone_non_empty :: proc(s: string) -> string {
	if len(s) == 0 {
		return ""
	}
	return strings.clone(s)
}

own_module_strings :: proc(module: ^Module) {
	module.file = clone_non_empty(module.file)
	for &scene in module.scenes {
		scene.name = clone_non_empty(scene.name)
		scene.path = clone_non_empty(scene.path)
		scene.widget = clone_non_empty(scene.widget)
		for &stmt in scene.statements {
			stmt.text = clone_non_empty(stmt.text)
			stmt.image_src = clone_non_empty(stmt.image_src)
			stmt.show_if = clone_non_empty(stmt.show_if)
			stmt.enable_if = clone_non_empty(stmt.enable_if)
			stmt.effect = clone_non_empty(stmt.effect)
			stmt.transfer.target.scene_ref = clone_non_empty(stmt.transfer.target.scene_ref)
			stmt.transfer.target.module_path = clone_non_empty(stmt.transfer.target.module_path)
			stmt.speaker.scene_ref = clone_non_empty(stmt.speaker.scene_ref)
			stmt.speaker.module_path = clone_non_empty(stmt.speaker.module_path)
		}
	}
}

free_string_if_non_empty :: proc(s: string) {
	if len(s) > 0 {
		delete(s)
	}
}

free_build_result :: proc(result: Build_Result) {
	for module in result.modules {
		free_string_if_non_empty(module.file)
		for scene in module.scenes {
			free_string_if_non_empty(scene.name)
			free_string_if_non_empty(scene.path)
			free_string_if_non_empty(scene.widget)
			for stmt in scene.statements {
				free_string_if_non_empty(stmt.text)
				free_string_if_non_empty(stmt.image_src)
				free_string_if_non_empty(stmt.show_if)
				free_string_if_non_empty(stmt.enable_if)
				free_string_if_non_empty(stmt.effect)
				free_string_if_non_empty(stmt.transfer.target.scene_ref)
				free_string_if_non_empty(stmt.transfer.target.module_path)
				free_string_if_non_empty(stmt.speaker.scene_ref)
				free_string_if_non_empty(stmt.speaker.module_path)
			}
			delete(scene.statements)
		}
		delete(module.scenes)
	}
	delete(result.modules)
	delete(result.errors)
	for file in result.source_files {
		delete(file)
	}
	delete(result.source_files)
}

build_result_from_source_for_test :: proc(source: string) -> (Build_Result, Lexer_Result) {
	lx := lexer.init(source, "test.saga")
	lexed := lexer.scan_lines(&lx)
	p := parser.init(lexed.lines[:], "test.saga")
	parsed := parser.parse(&p)

	build := Build_Result {
		modules      = make([dynamic]Module),
		errors       = make([dynamic]Diagnostic),
		source_files = make([dynamic]string),
	}
	for err in parsed.errors {
		append(&build.errors, err)
	}
	delete(parsed.errors)
	own_module_strings(&parsed.module)
	append(&build.modules, parsed.module)
	return build, lexed
}

@(test)
semantic_reports_unresolved_child_target_test :: proc(t: ^testing.T) {
	build, lexed := build_result_from_source_for_test(
		"# Village\n## GateWatch\n### WatchtowerRumor\n+ *-> [Press him for more](#.OldKey)\n### OldKey\n> key\n",
	)
	defer free_build_result(build)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	validate_targets(&build, "")
	testing.expect(t, len(build.errors) == 1)
	testing.expect(
		t,
		lexer.index_of(build.errors[0].message, "Village.GateWatch.WatchtowerRumor.OldKey") >= 0,
	)
}

@(test)
semantic_accepts_sibling_target_test :: proc(t: ^testing.T) {
	build, lexed := build_result_from_source_for_test(
		"# Village\n## GateWatch\n### WatchtowerRumor\n+ *-> [Press him for more](#..OldKey)\n### OldKey\n> key\n",
	)
	defer free_build_result(build)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	validate_targets(&build, "")
	testing.expect(t, len(build.errors) == 0)
}

@(test)
semantic_accepts_end_destination_test :: proc(t: ^testing.T) {
	build, lexed := build_result_from_source_for_test("# Main\n+ -> [Done](end:)\n")
	defer free_build_result(build)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	validate_targets(&build, "")
	testing.expect(t, len(build.errors) == 0)
}

@(test)
semantic_accepts_normal_transfer_to_widget_test :: proc(t: ^testing.T) {
	build, lexed := build_result_from_source_for_test(
		"# Main\n+ -> [Contacts](#.Contacts)\n@widget std:contacts\n## Contacts\n> People\n",
	)
	defer free_build_result(build)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	validate_targets(&build, "")
	testing.expect(t, len(build.errors) == 0)
}

@(test)
semantic_reports_unknown_widget_test :: proc(t: ^testing.T) {
	build, lexed := build_result_from_source_for_test(
		"@widget std:mystery\n# Mystery\n> Unknown\n",
	)
	defer free_build_result(build)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	validate_targets(&build, "")
	testing.expect(t, len(build.errors) == 1)
	testing.expect(t, lexer.index_of(build.errors[0].message, "unknown widget renderer") >= 0)
}

@(test)
semantic_reports_dialogue_without_speaker_test :: proc(t: ^testing.T) {
	build, lexed := build_result_from_source_for_test("# Main\n>> Hello.\n")
	defer free_build_result(build)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	validate_targets(&build, "")
	testing.expect(t, len(build.errors) == 1)
	testing.expect(t, lexer.index_of(build.errors[0].message, "no speaker") >= 0)
}

@(test)
semantic_reports_dialogue_speaker_that_is_not_character_test :: proc(t: ^testing.T) {
	build, lexed := build_result_from_source_for_test(
		"# Main\n>> [Speaker](#Speaker) Hello.\n@widget std:item\n# Speaker\n> Not a character.\n",
	)
	defer free_build_result(build)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	validate_targets(&build, "")
	testing.expect(t, len(build.errors) == 1)
	testing.expect(t, lexer.index_of(build.errors[0].message, "not a std:character") >= 0)
}

@(test)
semantic_reports_missing_root_relative_image_test :: proc(t: ^testing.T) {
	build, lexed := build_result_from_source_for_test(
		"# Main\n![Missing](/assets/images/does_not_exist.png)\n",
	)
	defer free_build_result(build)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	validate_targets(&build, "examples/test_drive")
	testing.expect(t, len(build.errors) == 1)
	testing.expect(t, lexer.index_of(build.errors[0].message, "missing image asset") >= 0)
}

@(test)
build_test_drive_story_test :: proc(t: ^testing.T) {
	build := build_story("examples/test_drive/main.saga")
	defer free_build_result(build)

	testing.expect(t, len(build.errors) == 0)
	testing.expect(t, len(build.modules) >= 7)
	testing.expect(t, len(build.source_files) >= 7)
}
