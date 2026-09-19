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
	type:    Token_Type,
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
	strings.write_string(builder, fmt.aprintfln("        \"scale\": %v,", cell.scale))
	strings.write_string(builder, fmt.aprintfln("        \"colspan\": %v,", cell.colspan))
	strings.write_string(builder, fmt.aprintfln("        \"rowspan\": %v,", cell.rowspan))
	strings.write_string(builder, fmt.aprintfln("        \"class\": \"%v\",", cell.class))
	strings.write_string(builder, fmt.aprintfln("        \"tag\": \"%v\",", cell.tag))
	strings.write_string(builder, fmt.aprintfln("        \"text\": \"%v\"", cell.text))
	strings.write_string(builder, fmt.aprint("      }"))
}

main :: proc() {
	if len(os.args) != 2 {
		fmt.printfln("Call the tool like so:\n%v path/to/txt/file", os.args[0])
		os.exit(0)
	}
	filepath := os.args[1]
	if !os.exists(filepath) {
		fmt.printfln("The file %v does not exist.", filepath)
		os.exit(0)
	}
	split_r, split_ok := strings.split(filepath, ".")
	fileout := fmt.aprintf("%v.json", split_r[0])

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
	fmt.println("\n--------------------------------------------------")
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
					word = ""
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
					word = ""
				} else {
					type = .Instruction
				}
				append(&tokens, Token{word = word, type = type, row = row, col = col})
			}
		}
		append(&tokens, Token{word = "", type = .EOL, row = row, col = col})
	}
	fmt.println("--------------------------------------------------\n")
	row += 1
	append(&tokens, Token{word = "", type = .EOF, row = row, col = 1})

	assert(tokens[0].type == .Title) // Sanity check and is assumed in what follows

	/* Post-processing of tokens */

	num_cols := 1
	for token in tokens {
		num_cols = max(num_cols, token.col)
	}
	num_rows := row
	fmt.printfln("%v rows | %v columns.\n", num_rows, num_cols)

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
			class := "hcentered"
			if token.type == .Ingredient {
				class = "lcentered"
			}
			cell := Cell {
				render  = true,
				scale   = token.type == .Ingredient,
				colspan = 1,
				rowspan = 1,
				class   = class,
				tag     = "td",
				text    = strings.clone(token.word),
				type    = token.type,
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

	/* Resolve .Empty and .CopyUp: set render false and increment colspan */
	for subtable, i in tables {
		nrows := len(subtable)
		ncols := len(subtable[0])
		if i == 0 {
			subtable[0][0].tag = "th"
		}
		if (nrows == 1) & (ncols == 1) {
			subtable[0][0].colspan = num_cols
		}
		if nrows == 1 {continue}

		for c in 0 ..< ncols {
			parent_r := 0
			parent_empty_exists := false
			for r in 0 ..< nrows {
				cell := &subtable[r][c]
				if cell.type == .Instruction {
					parent_empty_exists = false
					parent_r = r
					continue
				}
				if cell.type == .CopyUp {
					assert(r > 0, fmt.aprintfln("Cell\n%v\nhas no cell above it to copy from."))
					subtable[parent_r][c].rowspan += 1
					cell.render = false
					continue
				}
				if cell.type == .Empty {
					if parent_empty_exists {
						subtable[parent_r][c].rowspan += 1
						cell.render = false
					} else {
						parent_empty_exists = true
						parent_r = r
					}
					continue
				}
			}
		}
	}

	// Print the table contents for debugging
	// for subtable, i in tables {
	// 	for row, j in subtable {
	// 		fmt.printfln("  row %v", j)
	// 		for col, k in row {
	// 			fmt.printfln("    col %v", k)
	// 			fmt.printfln("      %v", col)
	// 		}
	// 	}
	// }

	/* Write json file */

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	// preamble
	strings.write_string(&builder, "{\n")
	strings.write_string(&builder, fmt.aprintf("  \"title\": \"%v\",\n", tokens[0].word))
	strings.write_string(&builder, "  \"rows\": [\n")

	first_row := true
	for subtable in tables {
		for row in subtable {
			if !first_row {
				strings.write_string(&builder, ",\n")
			}
			strings.write_string(&builder, "    [\n")

			first_cell := true
			for &cell, k in row {
				if !cell.render {continue}
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
	}

	// postamble
	strings.write_string(&builder, "\n  ]")
	strings.write_string(&builder, "\n}\n")

	// For debugging
	// fmt.println("---------------------------------------------")
	// fmt.print(strings.to_string(builder))

	if os.exists(fileout) {
		os.remove(fileout)
		fmt.println("Removed old", fileout)
	}

	fileout_handle, err := os.open(fileout, os.O_CREATE | os.O_WRONLY, os.Permissions_Read_All)
	if err != nil {
		fmt.eprintln("Could not create file", fileout, ":", err)
		os.exit(1)
	}
	defer os.close(fileout_handle)

	fmt.fprint(fileout_handle, strings.to_string(builder))
	fmt.println("Wrote", fileout)
}
