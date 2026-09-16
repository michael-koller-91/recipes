// TODO: memory cleanup
package converter

import "core:fmt"
import "core:os"
import "core:strings"
import "core:unicode/utf8"

Token_Type :: enum {
	Title,
	Instruction,
	Ingredient,
	HSep, // empty line
	VSep, // '|'
	Empty, // '-'
	CopyUp, // '"'
	CopyLeft, // '+'
	EOL, // end of line
	EOF, // end of file,  TODO: is this needed?
	COUNT,
}

Token :: struct {
	word: string,
	type: Token_Type,
	col:  int,
	row:  int,
}

Cell :: struct {
	render:  bool,
	scale:   bool,
	colspan: int,
	rowspan: int,
	class:   string,
	tag:     string,
	text:    string,
}

clone_trim :: proc(s: string, allocator := context.allocator) -> string {
	return strings.clone(strings.trim_space(s), allocator = allocator)
}

element_count :: proc(subtable: ^[dynamic][dynamic]Token) -> (count: int) {
	count = 0
	for row in subtable {
		count += len(row)
	}
	return
}

write_cell :: proc(builder: ^strings.Builder, cell: ^Cell) {
	strings.write_string(builder, fmt.aprintln("      {"))
	strings.write_string(builder, fmt.aprintfln("        \"scale\": %v", cell.scale))
	strings.write_string(builder, fmt.aprintfln("        \"colspan\": %v", cell.colspan))
	strings.write_string(builder, fmt.aprintfln("        \"rowspan\": %v", cell.rowspan))
	strings.write_string(builder, fmt.aprintfln("        \"class\": \"%v\"", cell.class))
	strings.write_string(builder, fmt.aprintfln("        \"tag\": \"%v\"", cell.tag))
	strings.write_string(builder, fmt.aprintfln("        \"text\": \"%v\"", cell.text))
	strings.write_string(builder, fmt.aprint("      }"))
}

main :: proc() {
	filepath := "baked_oats.txt"

	file, ok := os.read_entire_file(filepath, context.allocator)
	defer delete(file)
	if ok != nil {
		panic(fmt.aprintfln("Could not open file '%v': %v", filepath, ok))
	}

	/* Tokenize txt file */

	tokens: [dynamic]Token

	it := string(file)
	title := true
	col := 1
	row := 0
	fmt.println("---------------------------------------------")
	for str in strings.split_lines_iterator(&it) {
		fmt.printfln("%v", str)
		row += 1
		if str == "" {
			append(&tokens, Token{word = "---------", type = .HSep, row = row, col = 1})
			append(&tokens, Token{word = "", type = .EOL, row = row, col = 1})
			continue
		}
		if title {
			append(&tokens, Token{word = clone_trim(str), type = .Title, row = row, col = 1})
			append(&tokens, Token{word = "", type = .EOL, row = row, col = 1})
			title = false
			continue
		}

		start := 0
		end := 0
		type: Token_Type
		for ch, curr in str {
			defer end += utf8.rune_size(ch)
			if ch == '|' {
				defer col += 1
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
				append(&tokens, Token{word = word, type = type, row = row, col = col})

				append(&tokens, Token{word = "|", type = .VSep, row = row, col = col})
			} else if curr + utf8.rune_size(ch) == len(str) {
				defer col = 1
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
				} else {
					type = .Instruction
				}
				append(&tokens, Token{word = word, type = type, row = row, col = col})
			}
		}
		append(&tokens, Token{word = "", type = .EOL, row = row, col = col})
	}
	row += 1
	append(&tokens, Token{word = "", type = .EOF, row = row, col = 1})
	fmt.println("---------------------------------------------")

	assert(tokens[0].type == .Title) // Sanity check and is assumed in what follows

	/* Post-processing of tokens */

	num_cols := 1
	for token in tokens {
		num_cols = max(num_cols, token.col)
	}
	num_rows := row
	fmt.printfln("%v rows | %v columns.", num_rows, num_cols)

	// Keep EOL only when it is used at the end of a row that is not followed by HSep
	i := 0
	prev_token: Token
	next_token: Token
	for i < len(tokens) {
		token := tokens[i]
		if i + 1 < len(tokens) {
			next_token = tokens[i + 1]
		}
		if i > 0 {
			prev_token = tokens[i - 1]
		}
		if (token.type == .EOL) & (next_token.type == .HSep) {
			ordered_remove(&tokens, i)
		} else if (token.type == .EOL) & (next_token.type == .EOF) {
			ordered_remove(&tokens, i)
		} else if (token.type == .EOL) & (prev_token.type == .HSep) {
			ordered_remove(&tokens, i)
		} else {
			i += 1
		}
	}

	/* Convert Token into Cell and arrange into a list of (2D) sub-tables */
	tables: [dynamic][dynamic][dynamic]Cell
	append(&tables, make([dynamic][dynamic]Cell))
	subtable := &tables[len(tables) - 1]
	append(subtable, make([dynamic]Cell))
	curr_row := &subtable[len(subtable) - 1]
	for token, i in tokens {
		if i + 1 < len(tokens) {
			next_token = tokens[i + 1]
		} else {
			assert(token.type == .EOF)
			break
		}
		if token.type == .VSep {continue}
		if token.type == .EOL {
			if next_token.type != .HSep {
				// Start a new row
				append(subtable, make([dynamic]Cell))
				curr_row = &subtable[len(subtable) - 1]
			}
		} else if token.type == .HSep {
			// Start a new subtable
			append(&tables, make([dynamic][dynamic]Cell))
			subtable = &tables[len(tables) - 1]
			// Start a new row
			append(subtable, make([dynamic]Cell))
			curr_row = &subtable[len(subtable) - 1]
		} else {
			cell := Cell {
				render  = true,
				scale   = token.type == .Ingredient,
				colspan = 1,
				rowspan = 1,
				class   = "hcentered",
				tag     = "td",
				text    = strings.clone(token.word),
			}
			append(curr_row, cell)
		}
	}

	// Make sure the number of elements in each row of a given subtable is the same
	for subtable, i in tables {
		n_cols := len(subtable[0])
		for row in subtable {
			if len(row) != n_cols {
				fmt.printfln("Subtable %v:", i)
				for row, j in subtable {
					fmt.printfln("  row %v", j)
					for col, k in row {
						fmt.printfln("    col %v", k)
						fmt.printfln("      %v", col)
					}
				}
				panic("All rows in above subtable need to have the same number of columns!")
			}
		}
	}

	// TODO: NEXT: loop for-columns, for-rows and check if vertical merging is necessary
	for subtable, i in tables {
		fmt.println()
		fmt.printfln("subtable %v", i)
		for row, j in subtable {
			fmt.printfln("  row %v", j)
			for col, k in row {
				fmt.printfln("    col %v", k)
				fmt.printfln("      %v", col)
			}
		}
	}
	assert(1 == 2)


	/* Convert tokens to cells */
	json_rows: [dynamic][dynamic]Cell
	{
		cells: [dynamic]Cell
		append(
			&cells,
			Cell {
				scale = false,
				colspan = num_cols,
				rowspan = 1,
				class = "hcentered",
				tag = "th",
				text = tokens[0].word,
			},
		)
		append(&json_rows, cells)
	}

	// for &subtable, i in tables {
	// 	if element_count(&subtable) == 1 {
	// 		token := subtable[0][0]
	// 		if token.type == .Title {continue}
	// 		append(&json_rows, make([dynamic]Cell))
	// 		append(
	// 			&json_rows[len(json_rows) - 1],
	// 			Cell {
	// 				scale = false,
	// 				colspan = num_cols,
	// 				rowspan = 1,
	// 				class = "hcentered",
	// 				tag = "td",
	// 				text = token.word,
	// 			},
	// 		)
	// 	}
	// 	fmt.printfln("subtable %v has %v elements", i, element_count(&subtable))
	// }
	// for cells in json_rows {
	// 	for cell in cells {
	// 		fmt.println(cell)
	// 	}
	// }


	for row, i in json_rows {
		fmt.printfln("row %v:", i)
		for cell in row {
			fmt.printfln("  %v", cell)
		}
	}

	/* Write json file */

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	// preamble
	strings.write_string(&builder, "{\n")
	strings.write_string(&builder, fmt.aprintf("  \"title\": \"%v\",\n", tokens[0].word))
	strings.write_string(&builder, "  \"rows\": [\n")

	first_row := true
	for row in json_rows {
		if !first_row {
			strings.write_string(&builder, ",\n")
		}
		strings.write_string(&builder, "    [\n")

		first_cell := true
		for &cell in row {
			if !first_cell {
				strings.write_string(&builder, ",\n")
			}
			write_cell(&builder, &cell)
			first_cell = false
		}
		strings.write_string(&builder, "\n")

		strings.write_string(&builder, "    ]")
		first_row = false
	}

	// postamble
	strings.write_string(&builder, "  \n]")
	strings.write_string(&builder, "\n}")

	fmt.println("---------------------------------------------")
	fmt.print(strings.to_string(builder))
}
