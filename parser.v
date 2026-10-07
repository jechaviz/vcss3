module vcss3

pub fn parse(input string) Stylesheet {
	source := strip_comments(input)
	mut rules := []Rule{}
	mut at_rules := []AtRule{}
	mut warnings := []string{}
	mut i := 0
	for i < source.len {
		i = skip_space(source, i)
		if i >= source.len {
			break
		}
		if source[i] == `@` {
			next, at_rule, warning := parse_at_rule(source, i)
			if at_rule.name != '' {
				at_rules << at_rule
			}
			if warning != '' {
				warnings << warning
			}
			i = if next > i { next } else { i + 1 }
			continue
		}
		open := find_top_level_char(source, i, `{`)
		if open < 0 {
			trailing := source[i..].trim_space()
			if trailing != '' {
				warnings << 'ignored trailing CSS: ' + trailing
			}
			break
		}
		close := matching_brace(source, open)
		if close < 0 {
			warnings << 'unterminated rule starting at byte ${i}'
			break
		}
		selector_text := source[i..open].trim_space()
		block := source[open + 1..close]
		selectors := split_top_level(selector_text, `,`).map(it.trim_space()).filter(it != '')
		declarations, declaration_warnings := parse_declarations(block)
		warnings << declaration_warnings
		if selectors.len > 0 {
			rules << Rule{
				selectors: selectors
				declarations: declarations
			}
		}
		i = close + 1
	}
	return Stylesheet{
		rules: rules
		at_rules: at_rules
		warnings: warnings
	}
}

pub fn parse_declarations(input string) ([]Declaration, []string) {
	mut declarations := []Declaration{}
	mut warnings := []string{}
	for part in split_top_level(input, `;`) {
		clean := part.trim_space()
		if clean == '' {
			continue
		}
		colon := find_top_level_char(clean, 0, `:`)
		if colon <= 0 {
			warnings << 'ignored declaration without colon: ' + clean
			continue
		}
		property := clean[..colon].trim_space().to_lower()
		mut value := clean[colon + 1..].trim_space()
		mut important := false
		low := value.to_lower()
		if low.ends_with('!important') {
			important = true
			value = value[..value.len - '!important'.len].trim_space()
		}
		if property == '' || value == '' {
			warnings << 'ignored empty declaration: ' + clean
			continue
		}
		declarations << Declaration{
			property: property
			value: value
			important: important
		}
	}
	return declarations, warnings
}

fn parse_at_rule(source string, start int) (int, AtRule, string) {
	mut i := start + 1
	for i < source.len && is_ident_char(source[i]) {
		i++
	}
	name := source[start + 1..i].trim_space().to_lower()
	if name == '' {
		return i, AtRule{}, 'invalid at-rule'
	}
	semicolon := find_top_level_char(source, i, `;`)
	open := find_top_level_char(source, i, `{`)
	if semicolon >= 0 && (open < 0 || semicolon < open) {
		return semicolon + 1, AtRule{
			name: name
			prelude: source[i..semicolon].trim_space()
		}, ''
	}
	if open < 0 {
		return source.len, AtRule{
			name: name
			prelude: source[i..].trim_space()
		}, 'unterminated @' + name
	}
	close := matching_brace(source, open)
	if close < 0 {
		return source.len, AtRule{
			name: name
			prelude: source[i..open].trim_space()
			block: source[open + 1..]
		}, 'unterminated @' + name + ' block'
	}
	return close + 1, AtRule{
		name: name
		prelude: source[i..open].trim_space()
		block: source[open + 1..close].trim_space()
	}, ''
}

fn strip_comments(input string) string {
	mut out := []u8{cap: input.len}
	mut i := 0
	for i < input.len {
		if i + 1 < input.len && input[i] == `/` && input[i + 1] == `*` {
			end_rel := input[i + 2..].index('*/') or { -1 }
			if end_rel < 0 {
				break
			}
			i += 2 + end_rel + 2
			continue
		}
		out << input[i]
		i++
	}
	return out.bytestr()
}

fn split_top_level(input string, separator u8) []string {
	mut out := []string{}
	mut start := 0
	mut quote := u8(0)
	mut paren := 0
	mut bracket := 0
	mut brace := 0
	mut escape := false
	for i := 0; i < input.len; i++ {
		ch := input[i]
		if quote != 0 {
			if escape {
				escape = false
				continue
			}
			if ch == `\\` {
				escape = true
				continue
			}
			if ch == quote {
				quote = 0
			}
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
			continue
		}
		match ch {
			`(` { paren++ }
			`)` { if paren > 0 { paren-- } }
			`[` { bracket++ }
			`]` { if bracket > 0 { bracket-- } }
			`{` { brace++ }
			`}` { if brace > 0 { brace-- } }
			else {}
		}
		if ch == separator && paren == 0 && bracket == 0 && brace == 0 {
			out << input[start..i]
			start = i + 1
		}
	}
	out << input[start..]
	return out
}

fn find_top_level_char(input string, start int, needle u8) int {
	mut quote := u8(0)
	mut paren := 0
	mut bracket := 0
	mut escape := false
	for i := start; i < input.len; i++ {
		ch := input[i]
		if quote != 0 {
			if escape {
				escape = false
				continue
			}
			if ch == `\\` {
				escape = true
				continue
			}
			if ch == quote {
				quote = 0
			}
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
			continue
		}
		if ch == `(` {
			paren++
			continue
		}
		if ch == `)` {
			if paren > 0 { paren-- }
			continue
		}
		if ch == `[` {
			bracket++
			continue
		}
		if ch == `]` {
			if bracket > 0 { bracket-- }
			continue
		}
		if ch == needle && paren == 0 && bracket == 0 {
			return i
		}
	}
	return -1
}

fn matching_brace(input string, open int) int {
	mut depth := 0
	mut quote := u8(0)
	mut escape := false
	for i := open; i < input.len; i++ {
		ch := input[i]
		if quote != 0 {
			if escape {
				escape = false
				continue
			}
			if ch == `\\` {
				escape = true
				continue
			}
			if ch == quote {
				quote = 0
			}
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
			continue
		}
		if ch == `{` {
			depth++
		} else if ch == `}` {
			depth--
			if depth == 0 {
				return i
			}
		}
	}
	return -1
}

fn skip_space(input string, start int) int {
	mut i := start
	for i < input.len && input[i] <= ` ` {
		i++
	}
	return i
}

fn is_ident_char(ch u8) bool {
	return (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`)
		|| (ch >= `0` && ch <= `9`) || ch == `-` || ch == `_`
}
