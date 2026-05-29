package main

Statement_Kind :: enum {
	Scene,
	Narration,
	Dialogue,
	Choice_Block,
	Goto,
}

Choice_Option :: struct {
	text:   string,
	target: string,
	token:  Token,
}

Statement :: struct {
	kind:    Statement_Kind,
	name:    string,
	text:    string,
	target:  string,
	choices: [dynamic]Choice_Option,
	token:   Token,
}

Story :: struct {
	title:      string,
	statements: [dynamic]Statement,
}

Parse_Error :: struct {
	message: string,
	token:   Token,
}

Parse_Result :: struct {
	story:  Story,
	errors: [dynamic]Parse_Error,
}
