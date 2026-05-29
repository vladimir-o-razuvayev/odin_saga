package main

import "core:fmt"
import "core:os"
import "core:path/filepath"

Build_Result :: struct {
	modules: [dynamic]Module,
	errors:  [dynamic]Diagnostic,
}

main :: proc() {
	args := os.args
	if len(args) != 3 {
		fmt.eprintln("usage: odin_saga <entry.saga> <output.html>")
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

	document := html.generate(result.modules[:], "Odin Saga")
	defer delete(document)
	if !os.write_entire_file(args[2], transmute([]byte)document) {
		fmt.eprintf("failed to write %s\n", args[2])
		os.exit(1)
	}

	fmt.printf("wrote %s\n", args[2])
}

build_story :: proc(entry_path: string) -> Build_Result {
	result := Build_Result {
		modules = make([dynamic]Module),
		errors  = make([dynamic]Diagnostic),
	}
	loaded := make([dynamic]string)
	defer delete(loaded)

	base_dir := filepath.dir(entry_path)
	load_module(&result, &loaded, base_dir, entry_path)
	return result
}

load_module :: proc(result: ^Build_Result, loaded: ^[dynamic]string, base_dir, path: string) {
	if has_loaded(loaded[:], path) {
		return
	}
	append(loaded, path)

	data, ok := os.read_entire_file(path)
	if !ok {
		append(
			&result.errors,
			Diagnostic {
				message = fmt.tprintf("failed to read module %q", path),
				pos = Source_Pos{file = path, line = 1, column = 1},
			},
		)
		return
	}
	defer delete(data)

	lx := lexer.init(string(data), path)
	lexed := lexer.scan_lines(&lx)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	p := parser.init(lexed.lines[:], path)
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

	append(&result.modules, parsed.module)

	for scene in parsed.module.scenes {
		for stmt in scene.statements {
			module_path := stmt.transfer.target.module_path
			if len(module_path) == 0 {
				continue
			}
			resolved_path := fmt.tprintf("%s%s", base_dir, module_path)
			load_module(result, loaded, base_dir, resolved_path)
		}
	}
}

has_loaded :: proc(loaded: []string, path: string) -> bool {
	for item in loaded {
		if item == path {
			return true
		}
	}
	return false
}

free_build_result :: proc(result: Build_Result) {
	for module in result.modules {
		for scene in module.scenes {
			delete(scene.statements)
		}
		delete(module.scenes)
	}
	delete(result.modules)
	delete(result.errors)
}
