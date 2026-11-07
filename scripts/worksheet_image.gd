class_name WorksheetImage
extends RefCounted

const MAX_BYTES: int = 25 * 1024 * 1024
const MAX_PIXELS: int = 12_000_000

static func be16(bytes: PackedByteArray, index: int) -> int:
	return (int(bytes[index]) << 8) | int(bytes[index+1])

static func be32(bytes: PackedByteArray, index: int) -> int:
	return (int(bytes[index]) << 24) | (int(bytes[index+1]) << 16) | (int(bytes[index+2]) << 8) | int(bytes[index+3])

static func dimensions(bytes: PackedByteArray) -> Vector2i:
	# Only inspect headers; do not allocate a pixel buffer before checking dimensions.
	if bytes.size() >= 24 and bytes.slice(0,8) == PackedByteArray([137,80,78,71,13,10,26,10]):
		if be32(bytes,8) != 13 or bytes.slice(12,16).get_string_from_ascii() != "IHDR":
			return Vector2i.ZERO
		return Vector2i(be32(bytes,16),be32(bytes,20))
	if bytes.size() < 4 or bytes[0] != 255 or bytes[1] != 216:
		return Vector2i.ZERO
	var offset: int = 2
	while offset+3 < bytes.size():
		if bytes[offset] != 255:
			return Vector2i.ZERO
		while offset < bytes.size() and bytes[offset] == 255:
			offset += 1
		if offset >= bytes.size():
			return Vector2i.ZERO
		var marker: int = bytes[offset]
		offset += 1
		if marker == 0xD9 or marker == 0xDA:
			return Vector2i.ZERO
		if marker == 0x01 or (marker >= 0xD0 and marker <= 0xD8):
			continue
		if offset+2 > bytes.size():
			return Vector2i.ZERO
		var length: int = be16(bytes,offset)
		if length < 2 or offset+length > bytes.size():
			return Vector2i.ZERO
		if marker in [0xC0,0xC1,0xC2,0xC3,0xC5,0xC6,0xC7,0xC9,0xCA,0xCB,0xCD,0xCE,0xCF]:
			if length < 8:
				return Vector2i.ZERO
			return Vector2i(be16(bytes,offset+5),be16(bytes,offset+3))
		offset += length
	return Vector2i.ZERO

static func allowed_size(size: Vector2i) -> bool:
	return size.x > 0 and size.y > 0 and int(size.x)*int(size.y) <= MAX_PIXELS
