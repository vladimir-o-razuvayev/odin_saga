package main

Source_Pos :: struct {
	file:   string,
	line:   int,
	column: int,
}

Source_Line :: struct {
	raw:    string,
	text:   string,
	indent: int,
	pos:    Source_Pos,
}

Diagnostic :: struct {
	message: string,
	pos:     Source_Pos,
}

Transfer_Kind :: enum {
	Normal,
	Once,
	Widget,
}

Target :: struct {
	scene_ref:   string,
	module_path: string,
	pos:         Source_Pos,
}

Transfer :: struct {
	kind:   Transfer_Kind,
	target: Target,
}

Statement_Kind :: enum {
	Passage,
	Choice,
	Transition,
	Effect,
}

Statement :: struct {
	kind:      Statement_Kind,
	text:      string,
	show_if:   string,
	enable_if: string,
	take_if:   string,
	effect:    string,
	transfer:  Transfer,
	pos:       Source_Pos,
}

Scene :: struct {
	name:       string,
	path:       string,
	depth:      int,
	widget:     string,
	statements: [dynamic]Statement,
	pos:        Source_Pos,
}

Module :: struct {
	file:   string,
	scenes: [dynamic]Scene,
}

Parse_Result :: struct {
	module: Module,
	errors: [dynamic]Diagnostic,
}

Lexer_Result :: struct {
	lines:  [dynamic]Source_Line,
	errors: [dynamic]Diagnostic,
}
