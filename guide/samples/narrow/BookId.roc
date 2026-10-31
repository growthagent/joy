BookId :: { value : I64 }.{
	from_i64 : I64 -> BookId
	from_i64 = |n| { value: n }

	to_i64 : BookId -> I64
	to_i64 = |id| id.value
}
