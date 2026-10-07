module vcss3

pub struct Declaration {
pub:
	property  string
	value     string
	important bool
}

pub struct Rule {
pub:
	selectors    []string
	declarations []Declaration
}

pub struct AtRule {
pub:
	name      string
	prelude   string
	block     string
}

pub struct Stylesheet {
pub:
	rules    []Rule
	at_rules []AtRule
	warnings []string
}

pub fn (sheet Stylesheet) declaration_count() int {
	mut total := 0
	for rule in sheet.rules {
		total += rule.declarations.len
	}
	return total
}

pub fn (rule Rule) property(name string) ?Declaration {
	needle := name.trim_space().to_lower()
	for declaration in rule.declarations {
		if declaration.property == needle {
			return declaration
		}
	}
	return none
}
