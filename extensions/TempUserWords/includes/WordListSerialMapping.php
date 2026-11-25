<?php

namespace MediaWiki\Extension\TempUserWords;

use InvalidArgumentException;
use MediaWiki\User\TempUser\SerialMapping;
use OutOfBoundsException;
use RuntimeException;

/**
 * Maps sequential temporary account indexes to readable word-list identifiers
 * like "SleepyCow24294".
 *
 * Words are chosen at random from configured adjective and noun lists, while
 * the trailing number is a 1-to-1 modular scramble of the sequential index
 * (5-digit numbers 10000-99999 for the first 90,000 accounts per year, scaling
 * seamlessly to more digits if needed). Because the scrambled number is
 * bijective on $index, generated names cannot collide within a given year.
 */
class WordListSerialMapping implements SerialMapping {
	/**
	 * Prime moduli and primitive roots taken from MediaWiki core's
	 * ScrambleMapping, starting at the 5-digit range (10000..99999).
	 *
	 * Each entry is [ $g, $p ] where $g is a primitive root modulo prime $p.
	 * Every $p^2 fits comfortably within signed 64-bit PHP integers.
	 */
	private const GENERATORS = [
		[ 51947, 90001 ],
		[ 519612, 900001 ],
		[ 5196144, 8999993 ],
		[ 51961523, 89999999 ],
	];

	private const INITIAL_BASE = 9999;

	/** @var string[] */
	private array $adjectives;

	/** @var string[] */
	private array $nouns;

	/**
	 * @param array $config The $wgAutoCreateTempUser['serialMapping'] array.
	 *   Supported optional keys:
	 *   - adjectives: string[]
	 *   - adjectivesFile: string
	 *   - nouns: string[]
	 *   - nounsFile: string
	 */
	public function __construct( array $config = [] ) {
		$this->adjectives = $this->resolveWordList(
			$config['adjectives'] ?? null,
			$config['adjectivesFile'] ?? __DIR__ . '/../data/adjectives.txt',
			'adjectives'
		);
		$this->nouns = $this->resolveWordList(
			$config['nouns'] ?? null,
			$config['nounsFile'] ?? __DIR__ . '/../data/nouns.txt',
			'nouns'
		);
	}

	/**
	 * @inheritDoc
	 */
	public function getSerialIdForIndex( int $index ): string {
		$adjective = $this->adjectives[random_int( 0, count( $this->adjectives ) - 1 )];
		$noun = $this->nouns[random_int( 0, count( $this->nouns ) - 1 )];
		$number = $this->scrambleIndex( $index );

		return $adjective . $noun . $number;
	}

	/**
	 * Bijectively map a positive integer index to a non-sequential number
	 * starting in the 5-digit range (10000..99999).
	 *
	 * @param int $index
	 * @return string
	 */
	public function scrambleIndex( int $index ): string {
		if ( $index <= 0 ) {
			return (string)$index;
		}

		$consumed = 0;
		$base = self::INITIAL_BASE;

		foreach ( self::GENERATORS as [ $g, $p ] ) {
			$bucketSize = $p - 1;
			$localIndex = $index - $consumed;
			if ( $localIndex <= $bucketSize ) {
				return (string)( $base + $this->powmod( $g, $localIndex, $p ) );
			}
			$consumed += $bucketSize;
			$base += $bucketSize;
		}

		throw new OutOfBoundsException( __METHOD__ . ": Index $index exceeds supported range" );
	}

	/**
	 * Compute ($base ^ $exponent) mod $modulus using 64-bit integer arithmetic.
	 *
	 * @param int $base
	 * @param int $exponent
	 * @param int $modulus
	 * @return int
	 */
	private function powmod( int $base, int $exponent, int $modulus ): int {
		$result = 1;
		$base %= $modulus;
		while ( $exponent > 0 ) {
			if ( ( $exponent & 1 ) === 1 ) {
				$result = ( $result * $base ) % $modulus;
			}
			$exponent >>= 1;
			if ( $exponent > 0 ) {
				$base = ( $base * $base ) % $modulus;
			}
		}
		return $result;
	}

	/**
	 * @param array|null $inlineWords
	 * @param string $filePath
	 * @param string $label
	 * @return string[]
	 */
	private function resolveWordList( ?array $inlineWords, string $filePath, string $label ): array {
		if ( $inlineWords !== null ) {
			$raw = $inlineWords;
		} else {
			if ( !is_readable( $filePath ) ) {
				throw new RuntimeException( __CLASS__ . ": Cannot read $label file: $filePath" );
			}
			$raw = file( $filePath, FILE_IGNORE_NEW_LINES );
			if ( $raw === false ) {
				throw new RuntimeException( __CLASS__ . ": Failed reading $label file: $filePath" );
			}
		}

		$words = [];
		foreach ( $raw as $entry ) {
			$line = trim( (string)$entry );
			if ( $line === '' || str_starts_with( $line, '#' ) ) {
				continue;
			}
			$normalized = str_replace( ' ', '', ucwords( $line ) );
			if ( $normalized !== '' ) {
				$words[] = $normalized;
			}
		}

		$words = array_values( array_unique( $words ) );
		if ( $words === [] ) {
			throw new InvalidArgumentException( __CLASS__ . ": Configured $label list is empty" );
		}

		return $words;
	}
}
