# TempUserWords

A lightweight MediaWiki extension for Davispedia that provides a word-list
`SerialMapping` (`word-list`) for temporary user accounts, producing usernames
like `~2026-ZestyCow61946`.

## Usage

Load the extension and configure `$wgAutoCreateTempUser` in `LocalSettings.php`:

```php
wfLoadExtension( 'TempUserWords' );

$wgAutoCreateTempUser = [
	'known' => true,
	'enabled' => true,
	'actions' => [
		'edit',
	],
	'genPattern' => '~$1',
	'matchPattern' => null,
	'reservedPattern' => '~$1',
	'serialProvider' => [
		'type' => 'local',
		'useYear' => true,
	],
	'serialMapping' => [
		'type' => 'word-list',
	],
	'expireAfterDays' => 90,
	'notifyBeforeExpirationDays' => 10,
];
```

## Word lists

Default word lists live in:

- `data/adjectives.txt`
- `data/nouns.txt`

One word per line; blank lines and `#` comments are ignored, and words are
normalized to PascalCase automatically.

You can also override the word lists from `LocalSettings.php` via optional keys
on `$wgAutoCreateTempUser['serialMapping']`:

- `adjectives` / `nouns`: inline arrays of strings
- `adjectivesFile` / `nounsFile`: paths to newline-delimited word list files

## Collision safety

Words are chosen at random, while the trailing number is a 1-to-1 modular
scramble of the sequential index (`10000`–`99999` for the first 90,000 temp
accounts per year, scaling to 6+ digits automatically). Because each index
maps to a unique number, generated usernames cannot collide within a year.
