module vcss3

fn test_parse_rules_and_important() {
	sheet := parse('body, html { margin: 0; color: rgb(1, 2, 3) } a:hover { text-decoration: none !important; }')
	assert sheet.rules.len == 2
	assert sheet.rules[0].selectors == ['body', 'html']
	margin := sheet.rules[0].property('margin') or { panic('margin missing') }
	assert margin.value == '0'
	dec := sheet.rules[1].property('text-decoration') or { panic('property missing') }
	assert dec.value == 'none'
	assert dec.important
}

fn test_parse_at_rule() {
	sheet := parse('@media (max-width: 600px) { body { display: block; } } @charset "utf-8";')
	assert sheet.at_rules.len == 2
	assert sheet.at_rules[0].name == 'media'
	assert sheet.at_rules[0].block.contains('display')
	assert sheet.at_rules[1].name == 'charset'
}
