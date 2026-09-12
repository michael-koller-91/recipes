package converter

import "core:fmt"
import "core:os"
import "core:strings"
import "core:unicode/utf8"

Token_Type :: enum {
	Title,
	Instruction,
	Ingredient,
	HSep,
	VSep,
	Empty,
	CopyUp,
	CopyLeft,
	EOL,
	EOF,
	COUNT,
}

Token :: struct {
	word: string,
	type: Token_Type,
}

Cell :: struct {
	colspan, rowspan: int,
}

clone_trim :: proc(s: string, allocator := context.allocator) -> string {
	return strings.clone(strings.trim_space(s), allocator = allocator)
}

main :: proc() {
	filepath := "baked_oats.txt"

	file, ok := os.read_entire_file(filepath, context.allocator)
	//defer delete(file)
	if ok != nil {
		panic(fmt.aprintfln("Could not open file '%v': %v", filepath, ok))
	}

	tokens: [dynamic]Token

	it := string(file)
	title := true
	fmt.println("---------------------------------------------")
	for str in strings.split_lines_iterator(&it) {
		fmt.printfln("%v", str)
		if str == "" {
			append(&tokens, Token{word = "---------", type = .HSep})
			append(&tokens, Token{word = "", type = .EOL})
			continue
		}
		if title {
			append(&tokens, Token{word = clone_trim(str), type = .Title})
			append(&tokens, Token{word = "", type = .EOL})
			title = false
			continue
		}

		start := 0
		end := 0
		type: Token_Type
		for ch, curr in str {
			defer end += utf8.rune_size(ch)
			if ch == '|' {
				defer start = curr + utf8.rune_size('|')
				type = .Instruction

				if utf8.rune_at_pos(str, start) == '*' {
					start += utf8.rune_size('*')
					type = .Ingredient
				}
				word := clone_trim(str[start:end])

				if word == "\"" {
					defer start = curr + utf8.rune_size('"')
					type = .CopyUp
				} else if word == "+" {
					defer start = curr + utf8.rune_size('+')
					type = .CopyLeft
				} else if word == "-" {
					defer start = curr + utf8.rune_size('-')
					type = .Empty
				}
				append(&tokens, Token{word = word, type = type})

				append(&tokens, Token{word = "|", type = .VSep})
			} else if curr + utf8.rune_size(ch) == len(str) {
				type = .Instruction
				word := clone_trim(str[start:])

				if word == "\"" {
					defer start = curr + utf8.rune_size('"')
					type = .CopyUp
				} else if word == "+" {
					defer start = curr + utf8.rune_size('+')
					type = .CopyLeft
				} else if word == "-" {
					defer start = curr + utf8.rune_size('-')
					type = .Empty
				}
				append(&tokens, Token{word = word, type = type})
			}
		}
		append(&tokens, Token{word = "", type = .EOL})
	}
	append(&tokens, Token{word = "", type = .EOF})
	fmt.println("---------------------------------------------")

	for token in tokens {
		// fmt.printfln("%v: %v", token.type, token.word)
	}

	col := 0
	cols := 1
	for token in tokens {
		if token.type == .EOF {break}
		if token.type == .HSep {continue}
		if token.type == .VSep {continue}
		if token.type == .Title {continue}

		if token.type == .EOL {
			cols = max(cols, col)
			col = 0
		} else {
			col += 1
		}
	}
	fmt.println("cols =", cols)
}
