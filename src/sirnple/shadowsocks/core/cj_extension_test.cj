package sirnple.shadowsocks.core

from std import unittest.testmacro.{Test, Expect}
from serialization import serialization.*

@Test
func testByteArrayPlus() {
    @Expect(Array<Byte>() + Array<Byte>(), Array<Byte>())
    @Expect(Array<Byte>() + [1u8], [1u8])
    @Expect([1u8] + Array<Byte>(), [1u8])
    @Expect([1u8] + [2u8], [1u8, 2u8])

    @Expect([1u8, 2u8] + [3u8, 4u8], [1u8, 2u8, 3u8, 4u8])

    @Expect([1u8, 2u8, 3u8, 4u8] + [5u8, 6u8], [1u8, 2u8, 3u8, 4u8, 5u8, 6u8])
}