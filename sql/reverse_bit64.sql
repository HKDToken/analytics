CREATE FUNCTION reverse_bit64(n BIT(64)) RETURNS BIT(64) IMMUTABLE STRICT PARALLEL SAFE LANGUAGE SQL AS $$
	SELECT
		((n & X'00000000000000FF') << 56) |
		((n & X'000000000000FF00') << 40) |
		((n & X'0000000000FF0000') << 24) |
		((n & X'00000000FF000000') << 8 ) |
		((n & X'000000FF00000000') >> 8 ) |
		((n & X'0000FF0000000000') >> 24) |
		((n & X'00FF000000000000') >> 40) |
		((n & X'FF00000000000000') >> 56);
$$;